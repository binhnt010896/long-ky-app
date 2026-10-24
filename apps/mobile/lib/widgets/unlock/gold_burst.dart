import 'dart:math';

import 'package:flutter/material.dart';
import 'package:ui_kit/ui_kit.dart';

/// A one-shot burst of gold motes from the centre: [progress] 0 → 1. Unlike
/// the ambient ParticleField it plays once, outward, and fades. [intensity] 1
/// is an ordinary unlock; a milestone passes more.
class GoldBurstPainter extends CustomPainter {
  GoldBurstPainter(this.progress, {this.intensity = 1, int seed = 7})
      : _rng = Random(seed);

  final double progress;
  final double intensity;
  final Random _rng;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final centre = size.center(Offset.zero);
    final reach = size.shortestSide * (0.55 + 0.2 * intensity);
    final count = (28 * intensity).round();
    final ease = Curves.easeOutCubic.transform(progress);
    final fade = (1 - progress).clamp(0.0, 1.0);
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 0.45 + _rng.nextDouble() * 0.55;
      final radius = 1.2 + _rng.nextDouble() * 2.6;
      final d = reach * speed * ease;
      // A little gravity: the motes settle as they fade.
      final p = centre +
          Offset(cos(angle) * d, sin(angle) * d + 14 * progress * progress);
      paint.color = Color.lerp(VSColors.gold, VSColors.goldBright, speed)!
          .withValues(alpha: fade * (0.5 + 0.5 * speed));
      canvas.drawCircle(p, radius * (1 - 0.4 * progress), paint);
    }
  }

  @override
  bool shouldRepaint(GoldBurstPainter old) =>
      old.progress != progress || old.intensity != intensity;
}
