import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:ui_kit/ui_kit.dart';

/// Placeholder art for a scene layer slot.
///
/// Each slot is keyed by the content layer's `placeholder` name and `role`; a
/// real sơn mài PNG / Rive later replaces the placeholder in the *same* slot
/// without changing the scene composition. Until then these gradients stand in.
class ScenePlaceholder extends StatelessWidget {
  const ScenePlaceholder({
    required this.placeholder,
    required this.role,
    required this.palette,
    super.key,
  });

  /// Content `placeholder` id, e.g. `era-scene`, `horizon-glow`, `ridge`.
  final String placeholder;

  /// Content role, e.g. `sky`, `overlay`, `mid`, `foreground`.
  final String? role;

  final VSEraPalette palette;

  @override
  Widget build(BuildContext context) {
    switch (placeholder) {
      case 'era-scene':
        return DecoratedBox(
          decoration: BoxDecoration(gradient: palette.sceneGradient),
        );
      case 'horizon-glow':
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, 0.55),
              radius: 0.9,
              colors: <Color>[palette.horizonGlow, palette.horizonGlow.withValues(alpha: 0)],
              stops: const <double>[0, 0.72],
            ),
          ),
        );
      case 'ridge':
        final near = role == 'foreground';
        return _Ridge(near: near, palette: palette);
      default:
        return const SizedBox.shrink();
    }
  }
}

/// A layered hill silhouette, echoing the design's clip-path ridges.
class _Ridge extends StatelessWidget {
  const _Ridge({required this.near, required this.palette});

  final bool near;
  final VSEraPalette palette;

  // Top-edge points (x fraction, y fraction), left→right; closed to the bottom.
  static const List<Offset> _far = <Offset>[
    Offset(0, 0.55), Offset(0.12, 0.46), Offset(0.26, 0.52), Offset(0.40, 0.40),
    Offset(0.55, 0.50), Offset(0.70, 0.38), Offset(0.82, 0.47), Offset(1.0, 0.42),
  ];
  static const List<Offset> _near = <Offset>[
    Offset(0, 0.70), Offset(0.15, 0.62), Offset(0.30, 0.72), Offset(0.48, 0.58),
    Offset(0.62, 0.70), Offset(0.78, 0.60), Offset(1.0, 0.68),
  ];

  @override
  Widget build(BuildContext context) {
    final points = near ? _near : _far;
    final fill = near
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF12241C), VSColors.lacquerRaised],
          )
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color.alphaBlend(palette.accent.withValues(alpha: 0.55),
                  const Color(0xFF1C3128)),
              const Color(0xFF1C3128),
            ],
          );

    Widget ridge = ClipPath(
      clipper: _RidgeClipper(points),
      child: DecoratedBox(decoration: BoxDecoration(gradient: fill)),
    );
    if (!near) {
      // Far ridge sits back a touch, softened.
      ridge = Opacity(
        opacity: 0.82,
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 1.2, sigmaY: 1.2),
          child: ridge,
        ),
      );
    }
    return ridge;
  }
}

class _RidgeClipper extends CustomClipper<Path> {
  const _RidgeClipper(this.points);
  final List<Offset> points;

  @override
  Path getClip(Size size) {
    final path = Path()..moveTo(0, size.height);
    for (final p in points) {
      path.lineTo(p.dx * size.width, p.dy * size.height);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(_RidgeClipper oldClipper) => oldClipper.points != points;
}
