import 'dart:math';

import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../state/providers.dart';
import '../../state/quiz_store.dart';
import '../../widgets/circle_icon_button.dart';
import '../../widgets/lang_toggle.dart';

/// Câu đố's landing screen: three ways to play, each remembering its own
/// best score. No streaks, badges or leaderboards — just "have you played
/// today" and "what's your best" (the delicate-UI rule).
class QuizHomeScreen extends ConsumerWidget {
  const QuizHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    final en = lang == Lang.en;
    final progress = ref.watch(quizProgressProvider).valueOrNull;
    final today = DateTime.now();
    final dailyDone = progress?.isDailyDoneOn(today) ?? false;
    final dailyBest = progress?.bestFor(QuizModeKey.daily);
    final randomBest = progress?.bestFor(QuizModeKey.random);

    return Scaffold(
      backgroundColor: VSColors.lacquer,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              VSSpacing.xl, VSSpacing.lg, VSSpacing.xl, VSSpacing.huge),
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleIconButton(
                  icon: Icons.arrow_back,
                  onTap: () =>
                      context.canPop() ? context.pop() : context.go('/sanh'),
                ),
                const Spacer(),
                const LangToggle(),
              ],
            ),
            const SizedBox(height: VSSpacing.xl),
            Text(en ? 'QUIZ' : 'CÂU ĐỐ', style: VSType.kicker),
            const SizedBox(height: VSSpacing.sm),
            Text(
              en
                  ? 'Test yourself on a thousand years of Việt history'
                  : 'Thử sức với nghìn năm sử Việt',
              style: VSType.title,
            ),
            const SizedBox(height: VSSpacing.xxl),
            _ModeCard(
              key: const ValueKey<String>('quiz-mode-daily'),
              icon: Icons.wb_sunny_outlined,
              title: en ? 'Today\'s quiz' : 'Câu đố hôm nay',
              subtitle: en
                  ? '5 questions, the same for everyone today'
                  : '5 câu hỏi, giống nhau cho mọi người hôm nay',
              done: dailyDone,
              best: dailyBest,
              en: en,
              onTap: () => context.push(
                '/sanh/cau-do/choi?mode=daily&seed=${dailySeed(today)}',
              ),
            ),
            const SizedBox(height: VSSpacing.lg),
            _ModeCard(
              key: const ValueKey<String>('quiz-mode-period'),
              icon: Icons.account_balance_outlined,
              title: en ? 'By dynasty' : 'Theo triều đại',
              subtitle: en
                  ? 'Pick one dynasty, 10 questions from its eras'
                  : 'Chọn một triều đại, 10 câu hỏi từ các kỷ nguyên của triều đại đó',
              done: false,
              best: null,
              en: en,
              onTap: () => _pickPeriod(context, ref, en),
            ),
            const SizedBox(height: VSSpacing.lg),
            _ModeCard(
              key: const ValueKey<String>('quiz-mode-random'),
              icon: Icons.shuffle,
              title: en ? 'Random' : 'Ngẫu nhiên',
              subtitle: en
                  ? '10 questions from the whole chronicle'
                  : '10 câu hỏi từ toàn bộ dòng sử',
              done: false,
              best: randomBest,
              en: en,
              onTap: () {
                final seed = Random().nextInt(1 << 31);
                context.push('/sanh/cau-do/choi?mode=random&seed=$seed');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPeriod(
      BuildContext context, WidgetRef ref, bool en) async {
    final dynasties = await ref.read(dynastiesProvider.future);
    if (!context.mounted) return;
    final period = await showModalBottomSheet<Period>(
      context: context,
      backgroundColor: VSColors.lacquerRaised,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: VSRadii.card),
        side: BorderSide(color: VSColors.goldBorder),
      ),
      builder: (sheetContext) => _PeriodPicker(dynasties: dynasties, en: en),
    );
    if (period == null || !context.mounted) return;
    final seed = Random().nextInt(1 << 31);
    context.push(
        '/sanh/cau-do/choi?mode=period&period=${period.id}&seed=$seed');
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.best,
    required this.en,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool done;
  final BestScore? best;
  final bool en;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(VSSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: VSRadii.cardAll,
          border: Border.all(color: VSColors.goldBorder),
          color: VSColors.inkPrimary.withValues(alpha: 0.03),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: VSColors.goldBorder),
              ),
              child: Icon(icon, size: 22, color: VSColors.gold),
            ),
            const SizedBox(width: VSSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                          child: Text(title,
                              style: VSType.cardTitle,
                              overflow: TextOverflow.ellipsis)),
                      if (done) ...<Widget>[
                        const SizedBox(width: VSSpacing.xs),
                        const Icon(Icons.check_circle,
                            size: 16, color: VSColors.goldBright),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: VSType.caption.copyWith(color: VSColors.inkMuted),
                  ),
                  if (best != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      en
                          ? 'Best: ${best!.score}/${best!.total}'
                          : 'Tốt nhất: ${best!.score}/${best!.total}',
                      style: VSType.caption.copyWith(color: VSColors.goldBright),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: VSColors.gold),
          ],
        ),
      ),
    );
  }
}

class _PeriodPicker extends StatelessWidget {
  const _PeriodPicker({required this.dynasties, required this.en});

  final List<Dynasty> dynasties;
  final bool en;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (sheetContext, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                en ? 'Choose a dynasty' : 'Chọn một triều đại',
                style: VSType.title.copyWith(fontSize: 17),
              ),
              const SizedBox(height: VSSpacing.md),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: dynasties.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: VSColors.goldBorder, height: 1),
                  itemBuilder: (itemContext, i) {
                    final period = dynasties[i].period;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(period.title.resolve(lang(en)),
                          style: VSType.cardTitle),
                      subtitle: Text(period.yearRange.display.resolve(lang(en)),
                          style: VSType.caption
                              .copyWith(color: VSColors.inkMuted)),
                      onTap: () => Navigator.of(itemContext).pop(period),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Lang lang(bool en) => en ? Lang.en : Lang.vi;
}
