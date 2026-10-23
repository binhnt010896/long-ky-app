import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../state/providers.dart';
import '../../state/reminder_service.dart';
import '../../state/today_store.dart';
import '../../telemetry/telemetry.dart';

/// "08:00" for [minutes] after midnight.
String reminderTimeLabel(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

/// Asks the system for permission and, if granted, turns the daily reminder on
/// at [minutes]. Returns whether it is now on. Logs `notif_optin`.
Future<bool> enableReminder(WidgetRef ref, int minutes) async {
  final granted = await ref.read(reminderSchedulerProvider).requestPermission();
  ref.read(telemetryProvider).event('notif_optin', <String, Object>{
    'granted': granted ? 1 : 0,
  });
  if (!granted) return false;
  await ref
      .read(todayPrefsProvider.notifier)
      .setReminder(on: true, minutes: minutes);
  return true;
}

/// Turns the reminder off (cancelling what is pending, via the sync provider).
Future<void> disableReminder(WidgetRef ref) async {
  ref.read(telemetryProvider).event('notif_toggle', <String, Object>{'on': 0});
  await ref.read(todayPrefsProvider.notifier).setReminder(on: false);
}

/// Lets the reader pick the reminder's time; null when dismissed.
Future<int?> pickReminderTime(BuildContext context, int initial) async {
  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
  );
  return t == null ? null : t.hour * 60 + t.minute;
}

/// Tells the reader the system refused, calmly, and where to change it.
void showReminderRefused(BuildContext context, bool en) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
    content: Text(en
        ? 'Notifications are off for Long Ký. You can allow them in your phone\'s settings.'
        : 'Thông báo của Long Ký đang tắt. Bạn có thể bật trong phần Cài đặt của máy.'),
  ));
}

/// Offers the daily reminder **once**, whatever the answer — never again
/// (the switch in Sảnh stays). Called after the first finished daily quiz and
/// after the first time the reader opens "Hôm nay", never at launch.
Future<void> maybeOfferReminder(BuildContext context, WidgetRef ref) async {
  if (ref.read(reminderSchedulerProvider) is NoopReminderScheduler) return;
  final prefs = await ref.read(todayPrefsProvider.future);
  if (prefs.asked || prefs.reminderOn || !context.mounted) return;
  // Marked before it is shown, so an interruption can't make it ask twice.
  await ref.read(todayPrefsProvider.notifier).markAsked();
  if (!context.mounted) return;
  final minutes = await showModalBottomSheet<int>(
    context: context,
    backgroundColor: VSColors.lacquerRaised,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: VSRadii.card),
      side: BorderSide(color: VSColors.goldBorder),
    ),
    builder: (_) => ReminderSheet(initialMinutes: prefs.reminderMinutes),
  );
  if (minutes == null || !context.mounted) return;
  final en = ref.read(langProvider) == Lang.en;
  if (!await enableReminder(ref, minutes) && context.mounted) {
    showReminderRefused(context, en);
  }
}

/// "Nhắc mỗi ngày?" — the one-time offer. Pops the chosen time (minutes after
/// midnight) for "Bật nhắc", or null for "Để sau".
class ReminderSheet extends ConsumerStatefulWidget {
  const ReminderSheet({required this.initialMinutes, super.key});
  final int initialMinutes;

  @override
  ConsumerState<ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends ConsumerState<ReminderSheet> {
  late int _minutes = widget.initialMinutes;

  @override
  Widget build(BuildContext context) {
    final en = ref.watch(langProvider) == Lang.en;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              en ? 'A note from history, every day?' : 'Mỗi ngày một trang sử?',
              style: VSType.title.copyWith(fontSize: 18),
            ),
            const SizedBox(height: VSSpacing.sm),
            Text(
              en
                  ? 'One figure or event for today, at the time you choose. No ads, and nothing leaves your phone. Turn it off any time in the Explore hall.'
                  : 'Mỗi ngày một nhân vật hay sự kiện của ngày hôm nay, vào giờ bạn chọn. Không quảng cáo, không gửi dữ liệu đi đâu. Tắt bất cứ lúc nào trong phần Khám phá.',
              style: VSType.bodySmall.copyWith(color: VSColors.inkBody),
            ),
            const SizedBox(height: VSSpacing.lg),
            GestureDetector(
              key: const ValueKey<String>('reminder-sheet-time'),
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                final picked = await pickReminderTime(context, _minutes);
                if (picked != null && mounted) setState(() => _minutes = picked);
              },
              child: Row(
                children: <Widget>[
                  const Icon(Icons.schedule, size: 20, color: VSColors.gold),
                  const SizedBox(width: VSSpacing.sm),
                  Text(en ? 'At' : 'Vào lúc', style: VSType.bodySmall),
                  const SizedBox(width: VSSpacing.sm),
                  Text(reminderTimeLabel(_minutes),
                      style: VSType.label.copyWith(color: VSColors.goldBright)),
                ],
              ),
            ),
            const SizedBox(height: VSSpacing.xl),
            GestureDetector(
              key: const ValueKey<String>('reminder-sheet-yes'),
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(_minutes),
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      VSColors.goldBright.withValues(alpha: 0.30),
                      VSColors.gold.withValues(alpha: 0.18),
                    ],
                  ),
                  borderRadius: VSRadii.pillAll,
                  border: Border.all(color: VSColors.goldBright),
                ),
                child: Text(en ? 'Remind me' : 'Bật nhắc',
                    style: VSType.label.copyWith(color: VSColors.inkPrimary)),
              ),
            ),
            const SizedBox(height: VSSpacing.xs),
            Center(
              child: TextButton(
                key: const ValueKey<String>('reminder-sheet-later'),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(en ? 'Not now' : 'Để sau',
                    style: VSType.label.copyWith(color: VSColors.inkMuted)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
