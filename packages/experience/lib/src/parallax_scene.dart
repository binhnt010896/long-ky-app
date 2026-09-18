import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

/// One depth plane of a [ParallaxScene].
///
/// [depth] is 0 (infinitely far — no motion) → 1 (nearest — full motion). Keep
/// [child] a stable, cache-able widget: the scene rebuilds the transforms each
/// frame but reuses the child elements, so heavy subtrees don't rebuild.
@immutable
class ParallaxLayer {
  const ParallaxLayer({required this.depth, required this.child})
      : assert(depth >= 0 && depth <= 1, 'depth must be 0..1');

  final double depth;
  final Widget child;
}

/// A layered, depth-parallaxed scene.
///
/// All layers fill the scene and shift opposite the [pointer] by
/// `pointer × depth × maxShift`. The whole thing is driven by a single
/// [Listenable] ([pointer]); only the transforms recompute per frame (one
/// rebuild/frame on the parallax path), and each layer is isolated behind a
/// [RepaintBoundary].
class ParallaxScene extends StatelessWidget {
  const ParallaxScene({
    required this.layers,
    required this.pointer,
    this.maxShift = 22,
    this.clip = true,
    super.key,
  });

  /// Layers back → front (paint order). Order is independent of [ParallaxLayer.depth].
  final List<ParallaxLayer> layers;

  /// Normalized pointer in [-1, 1]; `(0,0)` is rest. A [ParallaxController] fits.
  final ValueListenable<Offset> pointer;

  /// Pixels of travel at `depth == 1` and full pointer deflection.
  final double maxShift;

  /// Clip the parallax overflow to the scene bounds.
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final stack = AnimatedBuilder(
      animation: pointer,
      builder: (context, _) {
        final p = pointer.value;
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            for (final layer in layers)
              Transform.translate(
                offset: Offset(
                  p.dx * layer.depth * maxShift,
                  p.dy * layer.depth * maxShift,
                ),
                // Slight overscale so shifted layers never reveal an edge gap.
                child: Transform.scale(
                  scale: 1 + layer.depth * 0.08,
                  child: RepaintBoundary(child: layer.child),
                ),
              ),
          ],
        );
      },
    );
    return clip ? ClipRect(child: stack) : stack;
  }
}
