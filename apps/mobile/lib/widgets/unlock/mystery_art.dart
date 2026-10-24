import 'package:flutter/material.dart';
import 'package:ui_kit/ui_kit.dart';

/// Which placeholder shape the hidden art takes.
enum MysteryKind {
  avatar('assets/mystery/avatar.webp'),
  full('assets/mystery/full.webp'),
  hero('assets/mystery/hero.webp');

  const MysteryKind(this.asset);
  final String asset;
}

/// The frame and silhouette that stand in for art the reader has not opened
/// yet, with a "?" drawn in code (sharp at any size, and animated on reveal —
/// image models garble text). Fills its parent.
class MysteryArt extends StatelessWidget {
  const MysteryArt({
    required this.kind,
    this.questionOpacity = 1,
    this.questionLift = 0,
    this.questionScale,
    super.key,
  });

  final MysteryKind kind;

  /// 0..1; fades the "?" (used by the reveal).
  final double questionOpacity;

  /// How far the "?" has lifted away, in logical pixels.
  final double questionLift;

  /// The "?" size; by default 38 % of the shorter side.
  final double? questionScale;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final shortest = c.biggest.shortestSide.isFinite ? c.biggest.shortestSide : 120;
      final size = questionScale ?? (shortest * 0.38).clamp(18.0, 96.0);
      return Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            kind.asset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            // Never a blank hole if the asset is missing.
            errorBuilder: (_, __, ___) => const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: <Color>[Color(0xFF3A120E), VSColors.lacquerDeep],
                ),
              ),
            ),
          ),
          Center(
            child: Opacity(
              opacity: questionOpacity.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, -questionLift),
                child: Text(
                  '?',
                  key: const ValueKey<String>('mystery-question'),
                  style: VSType.displayLarge.copyWith(
                    fontSize: size,
                    height: 1,
                    color: VSColors.goldBright,
                    shadows: const <Shadow>[
                      Shadow(color: VSColors.goldGlow, blurRadius: 24),
                      Shadow(color: Color(0xCC000000), blurRadius: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
