import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../app_router.dart';
import '../telemetry/telemetry.dart';
import 'providers.dart';
import 'today_provider.dart';
import 'today_store.dart';
import 'unlock_store.dart';

/// How many days ahead the reminder is scheduled. Small on purpose: iOS keeps
/// only 64 pending notifications per app, and the schedule is rebuilt on every
/// app start anyway.
const int kReminderDays = 14;

/// One scheduled reminder.
class ReminderEntry {
  const ReminderEntry({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
  });

  /// The calendar day as `yyyymmdd`, so a day is only ever scheduled once.
  final int id;

  /// When it fires, in the device's local time.
  final DateTime at;
  final String title;
  final String body;

  @override
  bool operator ==(Object other) =>
      other is ReminderEntry &&
      other.id == id &&
      other.at == at &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode => Object.hash(id, at, title, body);
}

/// The reminders for the next [days] days at [minutes] past local midnight,
/// each carrying that day's "Hôm nay" pick. A time already past is skipped.
/// Pure: the picks are computed on the device, so no server is involved.
List<ReminderEntry> buildReminderEntries({
  required TodayContext context,
  required DateTime now,
  required int minutes,
  required Lang lang,
  int days = kReminderDays,
}) {
  final entries = <ReminderEntry>[];
  for (var i = 0; entries.length < days && i < days + 1; i++) {
    final at =
        DateTime(now.year, now.month, now.day + i, minutes ~/ 60, minutes % 60);
    if (!at.isAfter(now.add(const Duration(minutes: 1)))) continue;
    final view = context.viewFor(DateTime(at.year, at.month, at.day));
    if (view == null) continue;
    entries.add(ReminderEntry(
      id: at.year * 10000 + at.month * 100 + at.day,
      at: at,
      title: todayKicker(view.item, lang),
      body: '${view.title.resolve(lang)} · ${lang == Lang.en ? "Today's gift is waiting" : 'Quà hôm nay đang chờ bạn'}',
    ));
  }
  return entries;
}

/// The device-notification seam: the real plugin in the app, a no-op on web,
/// desktop and in tests (which swap in a recording fake).
abstract class ReminderScheduler {
  /// Prepares the plugin. [onOpen] runs when the reader taps a reminder while
  /// the app is running.
  Future<void> init(void Function() onOpen);

  /// True when the app was started by tapping a reminder.
  Future<bool> launchedByReminder();

  /// Asks the OS for permission to notify; false when refused.
  Future<bool> requestPermission();

  /// Replaces every pending reminder with [entries].
  Future<void> replaceAll(List<ReminderEntry> entries);

  Future<void> cancelAll();
}

class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();
  @override
  Future<void> init(void Function() onOpen) async {}
  @override
  Future<bool> launchedByReminder() async => false;
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<void> replaceAll(List<ReminderEntry> entries) async {}
  @override
  Future<void> cancelAll() async {}
}

/// flutter_local_notifications, scheduled **inexactly**: a history note need
/// not arrive on the minute, and exact alarms are denied by default for new
/// installs on Android 14 (they would need SCHEDULE_EXACT_ALARM).
class LocalReminderScheduler implements ReminderScheduler {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'hom_nay',
      'Hôm nay',
      channelDescription: 'Nhắc mỗi ngày: nhân vật hay sự kiện của ngày hôm nay',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );

  void Function()? _onOpen;
  Future<void>? _initializing;

  /// Initialises the plugin once; later calls only replace the tap callback.
  @override
  Future<void> init(void Function() onOpen) {
    _onOpen = onOpen;
    return _ensureInit();
  }

  Future<void> _ensureInit() => _initializing ??= _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_longky'),
        // Never prompt at launch: permission is asked only after the reader
        // says yes in the app (requestPermission).
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (_) => _onOpen?.call(),
    );

  @override
  Future<bool> launchedByReminder() async {
    await _ensureInit();
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    await _ensureInit();
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Android 13+ shows the OS prompt; older versions need none (true).
        return await _plugin
                .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin>()
                ?.requestNotificationsPermission() ??
            false;
      case TargetPlatform.iOS:
        return await _plugin
                .resolvePlatformSpecificImplementation<
                    IOSFlutterLocalNotificationsPlugin>()
                ?.requestPermissions(alert: true, sound: true) ??
            false;
      default:
        return false;
    }
  }

  @override
  Future<void> replaceAll(List<ReminderEntry> entries) async {
    await _plugin.cancelAllPendingNotifications();
    for (final e in entries) {
      await _plugin.zonedSchedule(
        id: e.id,
        // An absolute instant, expressed in UTC: right in any timezone, with no
        // timezone database to load.
        scheduledDate:
            tz.TZDateTime.fromMillisecondsSinceEpoch(tz.UTC, e.at.millisecondsSinceEpoch),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: e.title,
        body: e.body,
      );
    }
  }

  @override
  Future<void> cancelAll() => _plugin.cancelAllPendingNotifications();
}

final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  final mobile = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  return mobile ? LocalReminderScheduler() : const NoopReminderScheduler();
});

/// Opens today's pick: marks it opened, logs it, and goes to `/hom-nay` (which
/// resolves the pick and redirects to its page).
///
/// Completes when the reader comes back from the page.
Future<void> openToday(WidgetRef ref, {required String source}) {
  ref.read(todayPrefsProvider.notifier).markOpened(DateTime.now());
  // With nothing left to unlock, opening "Hôm nay" is what keeps the streak.
  ref.read(unlockProvider.notifier).countToday();
  _logOpen(ref.read(telemetryProvider), source);
  return ref.read(routerProvider).push<void>('/hom-nay');
}

void _logOpen(Telemetry telemetry, String source) {
  telemetry.event('today_open', <String, Object>{'source': source});
}

/// The cold-start tap is handled once per process: the sync below re-runs on
/// every preference, content or language change and must not re-navigate.
bool _launchHandled = false;

/// Keeps the device's reminders in step with the reader's choice, the content
/// and the language, and opens "Hôm nay" when a reminder is tapped. Watched
/// for the app's lifetime; does nothing until the reader turns the reminder on.
final reminderSyncProvider = Provider<void>((ref) {
  final scheduler = ref.watch(reminderSchedulerProvider);
  final prefs = ref.watch(todayPrefsProvider).valueOrNull;
  final context = ref.watch(todayContextProvider).valueOrNull;
  final lang = ref.watch(langProvider);
  if (prefs == null) return;

  if (!prefs.reminderOn) {
    // Nothing was ever scheduled for a reader who was never asked.
    if (!prefs.asked) return;
    scheduler.cancelAll().catchError(
        (Object e, StackTrace s) => reportNonFatal(e, s, reason: 'reminder.cancel'));
    return;
  }
  if (context == null) return;
  () async {
    try {
      await scheduler.init(() {
        ref.read(todayPrefsProvider.notifier).markOpened(DateTime.now());
        ref.read(routerProvider).go('/hom-nay');
        _logOpen(ref.read(telemetryProvider), 'notification');
      });
      await scheduler.replaceAll(buildReminderEntries(
        context: context,
        now: DateTime.now(),
        minutes: prefs.reminderMinutes,
        lang: lang,
      ));
      if (!_launchHandled && await scheduler.launchedByReminder()) {
        _launchHandled = true;
        ref.read(routerProvider).go('/hom-nay');
        _logOpen(ref.read(telemetryProvider), 'notification');
      }
    } catch (e, s) {
      reportNonFatal(e, s, reason: 'reminder.sync');
    }
  }();
});
