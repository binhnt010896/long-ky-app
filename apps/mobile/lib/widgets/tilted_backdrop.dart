import 'package:core_domain/core_domain.dart';
import 'package:experience/experience.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';

import '../screens/era/widgets/era_scene_backdrop.dart';
import '../state/providers.dart';

/// A single-page immersive scaffold: owns a [ParallaxController] (+ tilt driver
/// on flagship) and paints the era backdrop behind [child].
///
/// Home manages its own shared controller across pages; Hub and Timeline are
/// single pages, so this owns the tilt lifecycle for them.
class TiltedBackdrop extends ConsumerStatefulWidget {
  const TiltedBackdrop({
    required this.era,
    required this.palette,
    required this.child,
    this.scrim = 0.0,
    super.key,
  });

  final Era era;
  final VSEraPalette palette;
  final Widget child;

  /// A flat black overlay (0–1) between the scene and [child]. Reading surfaces
  /// (the timeline) darken the bright dawn scene so light text stays legible;
  /// hero screens (Home/Hub) leave it at 0.
  final double scrim;

  @override
  ConsumerState<TiltedBackdrop> createState() => _TiltedBackdropState();
}

class _TiltedBackdropState extends ConsumerState<TiltedBackdrop> {
  final ParallaxController _pointer = ParallaxController();
  TiltParallaxDriver? _tilt;

  @override
  void initState() {
    super.initState();
    if (ref.read(tierProvider).capabilities.tilt) {
      _tilt = TiltParallaxDriver(_pointer)..start();
    }
  }

  @override
  void dispose() {
    _tilt?.dispose();
    _pointer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        EraSceneBackdrop(
          era: widget.era,
          pointer: _pointer,
          palette: widget.palette,
        ),
        if (widget.scrim > 0)
          IgnorePointer(
            child: ColoredBox(
              color: VSColors.lacquerVoid.withValues(alpha: widget.scrim),
            ),
          ),
        widget.child,
      ],
    );
  }
}
