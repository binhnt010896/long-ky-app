import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';

import '../state/providers.dart';

/// One step of a map screen's tour.
class MapTourStep {
  const MapTourStep({
    required this.id,
    required this.icon,
    required this.vi,
    required this.en,
  });

  /// Names what the screen should light up; the screen's `targetFor` maps it
  /// to a rect (street map: `map`, `card`; atlas: `map`, `timeline`).
  final String id;
  final IconData icon;

  /// Body text; `**bold**` spans are rendered gold.
  final String vi;
  final String en;
}

const List<MapTourStep> kStreetTourSteps = <MapTourStep>[
  MapTourStep(
    id: 'map',
    icon: Icons.touch_app_outlined,
    vi: 'Chạm vào một **con đường vàng** để biết nó mang tên nhân vật hay sự kiện nào.',
    en: 'Tap a **gold street** to see which figure or event it is named for.',
  ),
  MapTourStep(
    id: 'card',
    icon: Icons.person_search_outlined,
    vi: 'Bấm **Xem nhân vật** (hoặc Xem sự kiện) để mở trang chi tiết.',
    en: 'Tap **View figure** (or View event) to open the detail page.',
  ),
];

const List<MapTourStep> kAtlasTourSteps = <MapTourStep>[
  MapTourStep(
    id: 'map',
    icon: Icons.touch_app_outlined,
    vi: 'Chạm vào một **vùng** trên bản đồ để biết thế lực nào từng cai quản nơi ấy.',
    en: 'Tap a **region** to see which power held it.',
  ),
  MapTourStep(
    id: 'timeline',
    icon: Icons.swipe_outlined,
    vi: 'Kéo **thanh thời gian** để sang thời kỳ khác — bản đồ sẽ vẽ lại theo từng triều đại.',
    en: 'Drag the **timeline** to change period; the map redraws for each dynasty.',
  ),
];

/// A map screen's first-visit tour: a dim scrim with a spotlight, and a small
/// card with the text and Skip / Back / Next. Static, like the Home tour.
///
/// [targetFor] gives the *global* rect to light up for a step id (null = none,
/// a centred card). [onStep] fires when a step is shown (the screen uses it to
/// open a sample street for the second step); [onEnd] once, with `done` or
/// `skip` and the step reached.
class MapCoachmarks extends ConsumerStatefulWidget {
  const MapCoachmarks({
    required this.steps,
    required this.targetFor,
    required this.onStep,
    required this.onEnd,
    this.keyPrefix = 'street',
    this.nameVi = 'bản đồ đường phố',
    this.nameEn = 'Street map',
    super.key,
  });

  final List<MapTourStep> steps;

  /// Prefix of the widget keys (`<prefix>-coach-text|next|back|skip`).
  final String keyPrefix;

  /// Screen name for the screen-reader label, in each language.
  final String nameVi;
  final String nameEn;

  final Rect? Function(String stepId) targetFor;
  final void Function(int step) onStep;
  final void Function(String result, int step) onEnd;

  @override
  ConsumerState<MapCoachmarks> createState() => _MapCoachmarksState();
}

class _MapCoachmarksState extends ConsumerState<MapCoachmarks> {
  int _step = 0;
  Rect? _target;
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onStep(0));
  }

  void _end(String result) {
    if (_ended) return;
    _ended = true;
    widget.onEnd(result, _step);
  }

  void _go(int to) {
    setState(() {
      _step = to;
      _target = null;
    });
    widget.onStep(to);
  }

  /// The target may not exist yet (the card opens a frame after the step), so
  /// it is measured after every layout until it appears.
  void _measure() {
    final box = context.findRenderObject();
    final global = widget.targetFor(widget.steps[_step].id);
    Rect? local;
    if (global != null && box is RenderBox && box.hasSize) {
      local = Rect.fromPoints(
        box.globalToLocal(global.topLeft),
        box.globalToLocal(global.bottomRight),
      );
    }
    if (local != _target && mounted) setState(() => _target = local);
  }

  @override
  Widget build(BuildContext context) {
    final en = ref.watch(langProvider) == Lang.en;
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final step = widget.steps[_step];
    final last = _step == widget.steps.length - 1;
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());

    final hole = _target?.inflate(8);
    // The card sits on the side of the spotlight with more room.
    final below = hole != null && hole.center.dy < size.height / 2;
    final fade = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    final card = _TourCard(
      key: ValueKey<int>(_step),
      step: step,
      keyPrefix: widget.keyPrefix,
      name: en ? widget.nameEn : widget.nameVi,
      index: _step,
      total: widget.steps.length,
      en: en,
      last: last,
      onNext: () => last ? _end('done') : _go(_step + 1),
      onBack: _step == 0 ? null : () => _go(_step - 1),
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
            // Swallows touches so a stray pan can't move the map underneath.
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
    final scrim = Paint()..color = VSColors.lacquer.withValues(alpha: 0.72);
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

class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.step,
    required this.keyPrefix,
    required this.name,
    required this.index,
    required this.total,
    required this.en,
    required this.last,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
    super.key,
  });

  final MapTourStep step;
  final String keyPrefix;
  final String name;
  final int index;
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
          ? '$name tour, step ${index + 1} of $total'
          : 'Hướng dẫn $name, bước ${index + 1}/$total',
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
                    key: ValueKey<String>('$keyPrefix-coach-text'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: VSSpacing.md),
            Row(
              children: <Widget>[
                for (var i = 0; i < total; i++)
                  Container(
                    width: i == index ? 16 : 5,
                    height: 5,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.circular(3)),
                      color: i <= index
                          ? VSColors.gold
                          : VSColors.inkPrimary.withValues(alpha: 0.3),
                    ),
                  ),
                const Spacer(),
                if (!last)
                  GestureDetector(
                    key: ValueKey<String>('$keyPrefix-coach-skip'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onSkip,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        en ? 'Skip' : 'Bỏ qua',
                        style: VSType.caption.copyWith(
                          color: VSColors.inkMuted,
                        ),
                      ),
                    ),
                  ),
                if (onBack != null)
                  GestureDetector(
                    key: ValueKey<String>('$keyPrefix-coach-back'),
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
                  key: ValueKey<String>('$keyPrefix-coach-next'),
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
                          ? (en ? 'Got it' : 'Hiểu rồi')
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
