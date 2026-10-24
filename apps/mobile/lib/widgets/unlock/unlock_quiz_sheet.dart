import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../state/providers.dart';
import '../../state/unlock_store.dart';

/// The one question asked about a hidden person or event, or null when the
/// content can't make a fair one. Built from the same published content as the
/// quiz screen, and the same on every visit to the same page.
final unlockQuestionProvider =
    FutureProvider.family<McqQuestion?, String>((ref, key) async {
  final eras = await ref.watch(erasProvider.future);
  final standalone = await ref.watch(standaloneEventsProvider.future);
  final people = await ref.watch(peopleProvider.future);
  return QuizGenerator(eras, standalone: standalone, people: people)
      .questionFor(key);
});

/// Whether today's quiz unlocks are used up.
final quizCapReachedProvider = Provider<bool>((ref) {
  final data = ref.watch(unlockProvider).valueOrNull;
  if (data == null) return false;
  return data.quizUnlocksOn(ref.watch(unlockClockProvider)()) >= kQuizUnlocksPerDay;
});

/// Opens the one-question sheet for [key]; the answer, once right, unlocks the
/// art. Does nothing when the day's cap is used (the page says so).
Future<void> showUnlockQuizSheet(
    BuildContext context, WidgetRef ref, String key) async {
  if (ref.read(quizCapReachedProvider)) return;
  var attempts = 0;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: VSColors.lacquerRaised,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: VSRadii.screen),
    ),
    builder: (_) => _UnlockQuizSheet(
      visitKey: key,
      onSolved: (n) => attempts = n,
    ),
  );
  // However the sheet was closed, a solved question unlocks.
  if (attempts > 0) {
    await ref.read(unlockProvider.notifier).unlockByQuiz(key, attempts: attempts);
  }
}

class _UnlockQuizSheet extends ConsumerStatefulWidget {
  const _UnlockQuizSheet({required this.visitKey, required this.onSolved});

  final String visitKey;
  final void Function(int attempts) onSolved;

  @override
  ConsumerState<_UnlockQuizSheet> createState() => _UnlockQuizSheetState();
}

class _UnlockQuizSheetState extends ConsumerState<_UnlockQuizSheet>
    with SingleTickerProviderStateMixin {
  final Set<int> _wrong = <int>{};
  int _attempts = 0;
  int? _right;
  late final AnimationController _shake = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 320));

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _pick(McqQuestion q, int i) {
    if (_right != null || _wrong.contains(i)) return;
    _attempts++;
    if (i == q.correctIndex) {
      HapticFeedback.mediumImpact();
      setState(() => _right = i);
      widget.onSolved(_attempts);
    } else {
      HapticFeedback.lightImpact();
      if (!MediaQuery.disableAnimationsOf(context)) _shake.forward(from: 0);
      setState(() => _wrong.add(i));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final en = lang == Lang.en;
    final q = ref.watch(unlockQuestionProvider(widget.visitKey)).valueOrNull;
    final source = q?.source;
    final meta = source == null
        ? ''
        : <String>[
            if (source.citation.section?.resolve(lang) case final s?) s,
            if (source.citation.author case final a?) a,
          ].join(' · ');
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            VSSpacing.xl, VSSpacing.xl, VSSpacing.xl, VSSpacing.xl),
        child: q == null
            ? const SizedBox(
                height: 120,
                child: Center(
                    child: CircularProgressIndicator(color: VSColors.gold)))
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(en ? 'UNLOCK THE PICTURE' : 'MỞ KHÓA ẢNH',
                        style: VSType.overline),
                    const SizedBox(height: VSSpacing.sm),
                    Text(q.prompt.resolve(lang), style: VSType.title),
                    const SizedBox(height: VSSpacing.lg),
                    AnimatedBuilder(
                      animation: _shake,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(
                            (1 - _shake.value) *
                                8 *
                                ((_shake.value * 6).floor().isEven ? 1 : -1),
                            0),
                        child: child,
                      ),
                      child: Column(
                        children: <Widget>[
                          for (var i = 0; i < q.options.length; i++)
                            _Option(
                              label: q.options[i].resolve(lang),
                              state: _right == i
                                  ? _S.right
                                  : _wrong.contains(i)
                                      ? _S.wrong
                                      : _S.idle,
                              onTap: () => _pick(q, i),
                            ),
                        ],
                      ),
                    ),
                    if (_wrong.isNotEmpty && _right == null) ...<Widget>[
                      const SizedBox(height: VSSpacing.sm),
                      Text(
                        en ? 'Not quite — try again' : 'Chưa đúng — thử lại nhé',
                        key: const ValueKey<String>('unlock-retry'),
                        style: VSType.bodySmall
                            .copyWith(color: VSColors.goldBright),
                      ),
                    ],
                    if (_right != null && source != null) ...<Widget>[
                      const SizedBox(height: VSSpacing.md),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(VSSpacing.md),
                        decoration: BoxDecoration(
                          color: VSColors.goldWash,
                          borderRadius: VSRadii.citationAll,
                          border: Border.all(color: VSColors.goldBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(source.summary.resolve(lang),
                                style: VSType.bodySmall),
                            const SizedBox(height: VSSpacing.sm),
                            Text(
                              <String>[
                                source.citation.work,
                                if (meta.isNotEmpty) meta,
                              ].join(' · '),
                              style: VSType.caption
                                  .copyWith(color: VSColors.goldBright),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: VSSpacing.lg),
                      GestureDetector(
                        key: const ValueKey<String>('unlock-continue'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => context.pop(),
                        child: Container(
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: VSColors.gold.withValues(alpha: 0.14),
                            borderRadius: VSRadii.pillAll,
                            border: Border.all(
                                color: VSColors.gold.withValues(alpha: 0.6)),
                          ),
                          child: Text(en ? 'Reveal ›' : 'Mở ảnh ›',
                              style: VSType.label
                                  .copyWith(color: VSColors.inkPrimary)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

enum _S { idle, right, wrong }

class _Option extends StatelessWidget {
  const _Option({required this.label, required this.state, required this.onTap});

  final String label;
  final _S state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = switch (state) {
      _S.right => VSColors.goldBright,
      _S.wrong => const Color(0x66C0524A),
      _S.idle => VSColors.goldBorder,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: VSSpacing.sm),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: state == _S.idle ? onTap : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              horizontal: VSSpacing.md, vertical: VSSpacing.md - 2),
          decoration: BoxDecoration(
            borderRadius: VSRadii.cardAll,
            border: Border.all(color: border),
            color: state == _S.right
                ? VSColors.gold.withValues(alpha: 0.16)
                : Colors.transparent,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: VSType.body.copyWith(
                    color: state == _S.wrong
                        ? VSColors.inkFaint
                        : VSColors.inkPrimary,
                    decoration: state == _S.wrong
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
              if (state == _S.right)
                const Icon(Icons.check_circle,
                    size: 18, color: VSColors.goldBright),
              if (state == _S.wrong)
                const Icon(Icons.close, size: 18, color: Color(0xFFC0524A)),
            ],
          ),
        ),
      ),
    );
  }
}
