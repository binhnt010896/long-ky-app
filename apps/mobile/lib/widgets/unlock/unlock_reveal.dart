import 'dart:math';

import 'package:experience/experience.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../state/providers.dart';
import 'gold_burst.dart';
import 'mystery_art.dart';

/// The reward animation: the mystery frame trembles and its "?" lifts away, a
/// gold light sweeps across, the real [revealed] art scales in, and a burst of
/// gold motes goes off. About 1.2 s; a tap skips it. With reduced motion (or
/// the reduced tier) it is a plain 300 ms crossfade with no particles.
class UnlockReveal extends ConsumerStatefulWidget {
  const UnlockReveal({
    required this.kind,
    required this.revealed,
    this.onDone,
    this.caption,
    this.milestone = false,
    super.key,
  });

  final MysteryKind kind;
  final Widget revealed;
  final VoidCallback? onDone;

  /// A line that ticks in at the bottom, e.g. "+1 · 35/116".
  final String? caption;

  /// The longer burst for a 7/30/100-day streak.
  final bool milestone;

  @override
  ConsumerState<UnlockReveal> createState() => UnlockRevealState();
}

class UnlockRevealState extends ConsumerState<UnlockReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _reduced = false;
  bool _buzzed = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this);
    _c.addListener(() {
      if (!_buzzed && !_reduced && _c.value >= 0.3) {
        _buzzed = true;
        HapticFeedback.mediumImpact();
      }
    });
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone?.call();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.value > 0) return;
    _reduced = MediaQuery.disableAnimationsOf(context) ||
        !ref.read(tierProvider).capabilities.particles;
    final ms = _reduced ? 300 : (widget.milestone ? 1800 : 1200);
    _c.duration = Duration(milliseconds: ms);
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Jumps to the end (a tap on the reveal does this).
  void skip() {
    if (_c.isCompleted) return;
    _c.value = 1;
  }

  double _span(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: skip,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          if (_reduced) {
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Opacity(
                    opacity: 1 - t, child: MysteryArt(kind: widget.kind)),
                Opacity(opacity: t, child: widget.revealed),
                if (widget.caption != null) _caption(t),
              ],
            );
          }
          final tremble = _span(t, 0, 0.3);
          final shake = sin(tremble * pi * 8) * 4 * (1 - tremble);
          final swap = _span(t, 0.3, 0.65);
          final scale = 0.92 + 0.08 * Curves.easeOutBack.transform(swap);
          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: <Widget>[
              Opacity(
                opacity: 1 - swap,
                child: Transform.translate(
                  offset: Offset(shake, 0),
                  child: MysteryArt(
                    kind: widget.kind,
                    questionOpacity: 1 - tremble,
                    questionLift: 30 * tremble,
                  ),
                ),
              ),
              Opacity(
                opacity: swap,
                child: Transform.scale(scale: scale, child: widget.revealed),
              ),
              // The gold light sweeping left to right.
              IgnorePointer(
                child: CustomPaint(painter: _SweepPainter(_span(t, 0.25, 0.7))),
              ),
              IgnorePointer(
                child: CustomPaint(
                  painter: GoldBurstPainter(_span(t, 0.35, 1),
                      intensity: widget.milestone ? 2 : 1),
                ),
              ),
              if (widget.caption != null) _caption(t),
            ],
          );
        },
      ),
    );
  }

  Widget _caption(double t) {
    final a = _span(t, 0.5, 0.7) * (1 - _span(t, 0.92, 1) * 0);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(VSSpacing.md),
        child: Opacity(
          opacity: a,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xCC060D0C),
              borderRadius: VSRadii.pillAll,
              border: Border.all(color: VSColors.goldBorder),
            ),
            child: Text(
              widget.caption!,
              key: const ValueKey<String>('reveal-caption'),
              style: VSType.label.copyWith(color: VSColors.goldBright),
            ),
          ),
        ),
      ),
    );
  }
}

class _SweepPainter extends CustomPainter {
  _SweepPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final band = size.width * 0.35;
    final x = -band + (size.width + band * 2) * progress;
    final rect = Rect.fromLTWH(x - band / 2, 0, band, size.height);
    final paint = Paint()
      ..shader = LinearGradient(colors: <Color>[
        VSColors.goldBright.withValues(alpha: 0),
        VSColors.goldBright.withValues(alpha: 0.55),
        VSColors.goldBright.withValues(alpha: 0),
      ]).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_SweepPainter old) => old.progress != progress;
}
