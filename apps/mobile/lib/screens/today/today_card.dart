import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../state/providers.dart';
import '../../state/reminder_service.dart';
import '../../state/today_provider.dart';
import '../../state/today_store.dart';
import 'reminder_sheet.dart';

/// "Hôm nay" at the top of the Sảnh: one figure or event for today, new every
/// day — an anniversary when there is one, otherwise the day's turn in the
/// year's rotation. Renders nothing until the pick is ready (never a spinner)
/// or when there is nothing to show.
class TodayCard extends ConsumerWidget {
  const TodayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(todayViewProvider).valueOrNull;
    if (view == null) return const SizedBox.shrink();
    final lang = ref.watch(langProvider);
    final en = lang == Lang.en;
    final opened =
        ref.watch(todayPrefsProvider).valueOrNull?.openedOn(DateTime.now()) ??
            false;
    final summary = view.summary?.resolve(lang);

    return Padding(
      padding: const EdgeInsets.only(bottom: VSSpacing.lg),
      child: GestureDetector(
        key: const ValueKey<String>('sanh-today-card'),
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          await openToday(ref, source: 'sanh');
          // Back from the page: the one moment to offer the reminder.
          if (context.mounted) await maybeOfferReminder(context, ref);
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
          decoration: BoxDecoration(
            color: VSColors.lacquerRaised.withValues(alpha: 0.6),
            borderRadius: VSRadii.cardAll,
            border: Border.all(color: VSColors.goldBorder),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      todayKicker(view.item, lang).toUpperCase(),
                      key: const ValueKey<String>('today-kicker'),
                      style: VSType.overline.copyWith(color: VSColors.goldBright),
                    ),
                    const SizedBox(height: 4),
                    Text(view.title.resolve(lang),
                        key: const ValueKey<String>('today-title'),
                        style: VSType.headline),
                    if (summary != null && summary.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: VSType.caption
                            .copyWith(color: VSColors.inkSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: VSSpacing.md),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: VSColors.gold.withValues(alpha: 0.14),
                  border: Border.all(color: VSColors.goldBright),
                ),
                child: Icon(
                  opened ? Icons.check : Icons.arrow_forward,
                  key: ValueKey<String>(opened ? 'today-opened' : 'today-unopened'),
                  size: 18,
                  color: VSColors.goldBright,
                  semanticLabel: opened
                      ? (en ? 'Read today' : 'Đã đọc hôm nay')
                      : (en ? 'Open' : 'Mở'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
