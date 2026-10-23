import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../telemetry/telemetry.dart';

/// 08:00, in minutes after midnight: where the reminder starts.
const int kDefaultReminderMinutes = 8 * 60;

/// What the reader has decided about "Hôm nay", persisted between launches.
class TodayPrefs {
  const TodayPrefs({
    this.openedDate,
    this.reminderOn = false,
    this.reminderMinutes = kDefaultReminderMinutes,
    this.asked = false,
  });

  /// `yyyy-mm-dd` of the last day "Hôm nay" was opened (for its ✓ mark).
  final String? openedDate;

  /// The opt-in daily reminder. Off until the reader says yes.
  final bool reminderOn;

  /// When the reminder fires, in minutes after local midnight.
  final int reminderMinutes;

  /// The reminder offer has been shown (and answered), so it is never made
  /// again; the switch in Sảnh stays.
  final bool asked;

  bool openedOn(DateTime day) => openedDate == dateKey(day);

  TodayPrefs copyWith({
    String? openedDate,
    bool? reminderOn,
    int? reminderMinutes,
    bool? asked,
  }) =>
      TodayPrefs(
        openedDate: openedDate ?? this.openedDate,
        reminderOn: reminderOn ?? this.reminderOn,
        reminderMinutes: reminderMinutes ?? this.reminderMinutes,
        asked: asked ?? this.asked,
      );
}

/// `yyyy-mm-dd` of [d]'s calendar day.
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

abstract class TodayStore {
  Future<TodayPrefs> load();
  Future<void> save(TodayPrefs prefs);
}

/// Same on-disk pattern as the other small stores; on web it lives in memory
/// only.
class FileTodayStore implements TodayStore {
  TodayPrefs? _cached;

  static Future<File?> _file() async {
    if (kIsWeb) return null;
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/today.json');
  }

  @override
  Future<TodayPrefs> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    try {
      final file = await _file();
      if (file == null || !file.existsSync()) return _cached = const TodayPrefs();
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map<String, dynamic>) return _cached = const TodayPrefs();
      final minutes = raw['reminderMinutes'];
      return _cached = TodayPrefs(
        openedDate: raw['openedDate'] is String ? raw['openedDate'] as String : null,
        reminderOn: raw['reminderOn'] == true,
        reminderMinutes: minutes is int && minutes >= 0 && minutes < 24 * 60
            ? minutes
            : kDefaultReminderMinutes,
        asked: raw['asked'] == true,
      );
    } catch (e, s) {
      reportNonFatal(e, s, reason: 'FileTodayStore.load');
      return _cached = const TodayPrefs();
    }
  }

  @override
  Future<void> save(TodayPrefs prefs) async {
    _cached = prefs;
    try {
      final file = await _file();
      if (file == null) return;
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(jsonEncode(<String, dynamic>{
        if (prefs.openedDate != null) 'openedDate': prefs.openedDate,
        'reminderOn': prefs.reminderOn,
        'reminderMinutes': prefs.reminderMinutes,
        'asked': prefs.asked,
      }));
      await tmp.rename(file.path);
    } catch (e, s) {
      reportNonFatal(e, s, reason: 'FileTodayStore.save');
    }
  }
}

final todayStoreProvider = Provider<TodayStore>((ref) => FileTodayStore());

class TodayPrefsNotifier extends AsyncNotifier<TodayPrefs> {
  @override
  Future<TodayPrefs> build() => ref.watch(todayStoreProvider).load();

  Future<void> _set(TodayPrefs next) async {
    state = AsyncData(next);
    await ref.read(todayStoreProvider).save(next);
  }

  Future<TodayPrefs> _current() async => state.valueOrNull ?? await future;

  /// "Hôm nay" was opened on [day].
  Future<void> markOpened(DateTime day) async {
    final p = await _current();
    if (p.openedOn(day)) return;
    await _set(p.copyWith(openedDate: dateKey(day)));
  }

  /// The reader answered the one-time offer (either way).
  Future<void> markAsked() async {
    final p = await _current();
    if (p.asked) return;
    await _set(p.copyWith(asked: true));
  }

  /// Turns the reminder on or off; [minutes] (when given) sets its time.
  Future<void> setReminder({required bool on, int? minutes}) async {
    final p = await _current();
    await _set(p.copyWith(reminderOn: on, reminderMinutes: minutes, asked: true));
  }
}

final todayPrefsProvider =
    AsyncNotifierProvider<TodayPrefsNotifier, TodayPrefs>(TodayPrefsNotifier.new);
