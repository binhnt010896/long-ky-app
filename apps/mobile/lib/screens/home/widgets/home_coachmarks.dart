import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../state/providers.dart';
import '../../../widgets/lang_toggle.dart';

/// One step of the first-run Home tour.
class CoachStep {
  const CoachStep({
    required this.id,
    required this.icon,
    required this.vi,
    required this.en,
  });

  /// Stable id handed to [HomeCoachmarks.targetFor] to locate what to light up
  /// (null result = no spotlight, a centred card).
  final String id;
  final IconData icon;

  /// Body text; `**bold**` spans are rendered gold.
  final String vi;
  final String en;
}

const List<CoachStep> kHomeCoachSteps = <CoachStep>[
  CoachStep(
    id: 'welcome',
    icon: Icons.translate_rounded,
    vi: '**Chào mừng đến Long Ký.** Chọn ngôn ngữ đọc, rồi cùng xem qua cách dùng.',
    en: '**Welcome to Long Ký.** Pick your reading language, then a quick tour.',
  ),
  CoachStep(
    id: 'era',
    icon: Icons.swap_horiz_rounded,
    vi: 'Vuốt **trái/phải** để qua các thời kỳ trong triều đại. Chạm để bước vào.',
    en: 'Swipe **left/right** through the eras of a dynasty. Tap to step in.',
  ),
  CoachStep(
    id: 'rail',
    icon: Icons.swap_vert_rounded,
    vi: 'Vuốt **lên/xuống** để đổi triều đại, hoặc kéo dải chấm này để tua nhanh.',
    en: 'Swipe **up/down** to change dynasty, or drag this rail to scrub.',
  ),
  CoachStep(
    id: 'timeline',
    icon: Icons.timeline_rounded,
    vi: '**Dòng thời gian**: toàn bộ sử Việt trên một trục.',
    en: '**Timeline**: all of Vietnamese history on one axis.',
  ),
  CoachStep(
    id: 'sanh',
    icon: Icons.account_balance_rounded,
    vi: '**Sảnh Long Ký**: câu đố, Chào cờ, đường phố, và đổi ngôn ngữ bất cứ lúc nào.',
    en: '**The Hall**: quizzes, Chào cờ, street names, and the language switch anytime.',
  ),
];

/// The first-run Home tour: a dim lacquer scrim with a spotlight cut-out, and
/// a small card carrying the text, the VI/EN toggle (the reader has not yet
/// had a chance to find it elsewhere) and Skip / Back / Next.
///
/// Static — no looping motion. [targetFor] maps a step id to the on-screen
/// rect to light up, in this widget's own coordinate space.
class HomeCoachmarks extends ConsumerStatefulWidget {
  const HomeCoachmarks({
    required this.targetFor,
    required this.onEnd,
    super.key,
  });

  final Rect? Function(String stepId, Size size) targetFor;

  /// Called once, with how it ended (`done` / `skip`) and the step reached.
  final void Function(String result, int step) onEnd;

  @override
  ConsumerState<HomeCoachmarks> createState() => _HomeCoachmarksState();
}

class _HomeCoachmarksState extends ConsumerState<HomeCoachmarks> {
  int _step = 0;
  Rect? _target;
  bool _ended = false;

  void _end(String result) {
    if (_ended) return;
    _ended = true;
    widget.onEnd(result, _step);
  }

  void _next() {
    if (_step == kHomeCoachSteps.length - 1) return _end('done');
    setState(() {
      _step++;
      _target = null;
    });
  }

  void _back() {
    if (_step == 0) return;
    setState(() {
      _step--;
      _target = null;
    });
  }

  /// Targets live in other widgets, so they are measured after layout and
  /// again whenever the window changes.
  void _measure(Size size) {
    final next = widget.targetFor(kHomeCoachSteps[_step].id, size);
    if (next != _target && mounted) setState(() => _target = next);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final en = lang == Lang.en;
    final size = MediaQuery.sizeOf(context);
    final step = kHomeCoachSteps[_step];
    final last = _step == kHomeCoachSteps.length - 1;
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure(size));

    final hole = _target?.inflate(8);
    final pad = MediaQuery.paddingOf(context);
    final below = hole != null && hole.center.dy < size.height / 2;

    final fade = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);

    final card = _CoachCard(
      key: ValueKey<int>(_step),
      step: step,
      stepIndex: _step,
      total: kHomeCoachSteps.length,
      en: en,
      last: last,
      onNext: _next,
      onBack: _step == 0 ? null : _back,
      onSkip: () => _end('skip'),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _end('skip');
      },
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Swallows touches so a stray swipe can't move the pagers below.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              onPanStart: (_) {},
              child: CustomPaint(painter: _SpotlightPainter(hole)),
            ),
            if (hole == null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: AnimatedSwitcher(duration: fade, child: card),
                ),
              )
            else
              Positioned(
                left: 24,
                right: 24,
                top: below ? hole.bottom + 16 : null,
                bottom: below
                    ? null
                    : (size.height - hole.top + 16).clamp(
                        pad.bottom + 16,
                        size.height,
                      ),
                child: AnimatedSwitcher(duration: fade, child: card),
              ),
          ],
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter(this.hole);
  final Rect? hole;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final scrim = Paint()..color = VSColors.lacquer.withValues(alpha: 0.78);
    if (hole == null) {
      canvas.drawPath(full, scrim);
      return;
    }
    final rr = RRect.fromRectAndRadius(hole!, const Radius.circular(14));
    canvas.drawPath(
      Path.combine(PathOperation.difference, full, Path()..addRRect(rr)),
      scrim,
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = VSColors.gold.withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.hole != hole;
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({
    required this.step,
    required this.stepIndex,
    required this.total,
    required this.en,
    required this.last,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
    super.key,
  });

  final CoachStep step;
  final int stepIndex;
  final int total;
  final bool en;
  final bool last;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final VoidCallback onSkip;

  List<InlineSpan> _spans(String s) {
    final parts = s.split('**');
    return <InlineSpan>[
      for (var i = 0; i < parts.length; i++)
        TextSpan(
          text: parts[i],
          style: i.isOdd
              ? const TextStyle(
                  color: VSColors.goldBright,
                  fontWeight: FontWeight.w600,
                )
              : null,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: en
          ? 'Tour, step ${stepIndex + 1} of $total'
          : 'Hướng dẫn, bước ${stepIndex + 1}/$total',
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
        decoration: BoxDecoration(
          color: VSColors.lacquerRaised.withValues(alpha: 0.98),
          borderRadius: VSRadii.cardAll,
          border: Border.all(color: VSColors.goldBorder),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x66000000), blurRadius: 20),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const LangToggle(),
                const Spacer(),
                GestureDetector(
                  key: const ValueKey<String>('coach-skip'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onSkip,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                    child: Text(
                      en ? 'Skip' : 'Bỏ qua',
                      style: VSType.caption.copyWith(color: VSColors.inkMuted),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: VSSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(step.icon, size: 22, color: VSColors.gold),
                const SizedBox(width: VSSpacing.md),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: VSType.body,
                      children: _spans(en ? step.en : step.vi),
                    ),
                    key: const ValueKey<String>('coach-text'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: VSSpacing.md),
            Row(
              children: <Widget>[
                // The first dot is filled from the start: choosing a language
                // already counts as progress.
                for (var i = 0; i < total; i++)
                  Container(
                    width: i == stepIndex ? 16 : 5,
                    height: 5,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.circular(3)),
                      color: i <= stepIndex
                          ? VSColors.gold
                          : VSColors.inkPrimary.withValues(alpha: 0.3),
                    ),
                  ),
                const Spacer(),
                if (onBack != null)
                  GestureDetector(
                    key: const ValueKey<String>('coach-back'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onBack,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        en ? 'Back' : 'Trước',
                        style: VSType.caption.copyWith(
                          color: VSColors.inkMuted,
                        ),
                      ),
                    ),
                  ),
                GestureDetector(
                  key: const ValueKey<String>('coach-next'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onNext,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    decoration: const BoxDecoration(
                      gradient: VSColors.goldSheen,
                      borderRadius: BorderRadius.all(Radius.circular(18)),
                    ),
                    child: Text(
                      last
                          ? (en ? 'Start' : 'Bắt đầu')
                          : (en ? 'Next' : 'Tiếp'),
                      style: VSType.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: VSColors.lacquerRaised,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
