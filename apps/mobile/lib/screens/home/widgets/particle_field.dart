import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Drifting ambient motes — the flagship-only atmosphere from the design's
/// `drift` keyframe. Gated by tier at the call site; this widget just draws.
///
/// One [AnimationController] repaints a [CustomPainter]; particles are computed
/// from per-mote seeds, so there's no per-frame allocation.
class ParticleField extends StatefulWidget {
  const ParticleField({
    required this.color,
    this.count = 18,
    this.seed = 7,
    super.key,
  });

  final Color color;
  final int count;
  final int seed;

  @override
  State<ParticleField> createState() => _ParticleFieldState();
}

class _ParticleFieldState extends State<ParticleField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Mote> _motes;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(widget.seed);
    _motes = List<_Mote>.generate(widget.count, (_) {
      return _Mote(
        x: rng.nextDouble(),
        y: 0.2 + rng.nextDouble() * 0.75,
        size: 1 + rng.nextDouble() * 2.4,
        phase: rng.nextDouble(),
        speed: 0.6 + rng.nextDouble() * 0.8,
        maxOpacity: 0.2 + rng.nextDouble() * 0.55,
      );
    });
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _ParticlePainter(
          motes: _motes,
          color: widget.color,
          progress: _controller,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _Mote {
  const _Mote({
    required this.x,
    required this.y,
    required this.size,
    required this.phase,
    required this.speed,
    required this.maxOpacity,
  });

  final double x;
  final double y;
  final double size;
  final double phase;
  final double speed;
  final double maxOpacity;
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({
    required this.motes,
    required this.color,
    required this.progress,
  }) : super(repaint: progress);

  final List<_Mote> motes;
  final Color color;
  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final m in motes) {
      // Loop each mote on its own phase; drift up ~26px and fade in/out.
      final t = (progress.value * m.speed + m.phase) % 1.0;
      final rise = 26 * t;
      final dx = m.x * size.width + 8 * t;
      final dy = m.y * size.height - rise;
      final opacity = m.maxOpacity * _fade(t);
      if (opacity <= 0.01) continue;
      paint.color = color.withValues(alpha: opacity);
      canvas.drawCircle(Offset(dx, dy), m.size, paint);
    }
  }

  /// Fade in over the first 12%, out over the last 12% (matches `drift`).
  double _fade(double t) {
    if (t < 0.12) return t / 0.12;
    if (t > 0.88) return (1 - t) / 0.12;
    return 1;
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.motes != motes;
}
