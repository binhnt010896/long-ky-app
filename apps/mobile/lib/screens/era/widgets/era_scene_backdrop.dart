import 'package:core_domain/core_domain.dart';
import 'package:experience/experience.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../theme/content_assets.dart';
import '../../home/widgets/particle_field.dart';
import '../../home/widgets/scene_placeholders.dart';
import 'scene_video_layer.dart';

/// The layered sơn mài parallax backdrop for an era — the scene only, no copy.
///
/// Each content scene slot becomes a [ParallaxLayer]. A slot with a real art
/// asset renders that image (fit by its role); a slot without one renders its
/// gradient placeholder; particle slots draw the ambient field (flagship only).
class EraSceneBackdrop extends StatelessWidget {
  const EraSceneBackdrop({
    required this.era,
    required this.pointer,
    this.palette,
    this.vignette = true,
    this.foregroundVisible = false,
    this.allowVideo = false,
    super.key,
  });

  final Era era;
  final ValueListenable<Offset> pointer;
  final VSEraPalette? palette;
  final bool vignette;

  /// When true, a scene slot that carries a `video` source plays it (looping,
  /// muted) over its still image — used on the Era Hub so the cover animates.
  /// Home and reading surfaces leave it false and stay static.
  final bool allowVideo;

  /// When true, the bottom of the vignette is kept light so the foreground
  /// (ridge) layers read as a visible parallax silhouette — used on Home, where
  /// the scene is the whole screen. Reading surfaces leave it false (their sheet
  /// or scrim covers the bottom anyway).
  final bool foregroundVisible;

  @override
  Widget build(BuildContext context) {
    final caps = context.caps;
    final p = palette ?? VSEraPalette.fallback;

    final layers = <ParallaxLayer>[];
    for (final slot in era.sceneLayers) {
      if (slot.role == AssetRole.particles) {
        if (!caps.particles) continue;
        layers.add(ParallaxLayer(
          depth: slot.depth ?? 1.0,
          child: ParticleField(color: p.particle),
        ));
        continue;
      }
      layers.add(ParallaxLayer(
        depth: slot.depth ?? 0.0,
        child: slot.isPlaceholder
            ? ScenePlaceholder(
                placeholder: slot.placeholder ?? 'era-scene',
                role: slot.role?.name,
                palette: p,
              )
            : _SceneLayerImage(slot: slot, allowVideo: allowVideo),
      ));
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ParallaxScene(
          layers: layers,
          pointer: pointer,
          maxShift: caps.parallax ? 22 : 0,
        ),
        if (vignette)
          IgnorePointer(child: _Vignette(light: foregroundVisible)),
      ],
    );
  }
}

/// Renders one art layer, fit and anchored by its semantic role.
class _SceneLayerImage extends StatelessWidget {
  const _SceneLayerImage({required this.slot, this.allowVideo = false});

  final AssetRef slot;
  final bool allowVideo;

  @override
  Widget build(BuildContext context) {
    // Reduced/trailer tiers use the static fallback; flagship prefers its
    // (currently identical) primary. Rive upgrades slot in here later.
    final path =
        context.caps.rive ? (slot.flagship ?? slot.reduced) : (slot.reduced ?? slot.flagship);
    if (path == null) return const SizedBox.shrink();

    final (BoxFit fit, Alignment align, double opacity) = switch (slot.role) {
      AssetRole.sky => (BoxFit.cover, Alignment.center, 1.0),
      AssetRole.overlay => (BoxFit.fitWidth, const Alignment(0, 0.55), 0.85),
      AssetRole.mid => (BoxFit.fitWidth, Alignment.bottomCenter, 1.0),
      AssetRole.foreground => (BoxFit.fitWidth, Alignment.bottomCenter, 1.0),
      _ => (BoxFit.cover, Alignment.center, 1.0),
    };

    Widget image = Image.asset(
      contentAssetKey(path),
      fit: fit,
      alignment: align,
      filterQuality: FilterQuality.medium,
      frameBuilder: fadeInImageFrame,
      // Missing art must never crash a screen — fall back to empty.
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );

    // Animated cover: play the looping video over the still, which stays as the
    // fade-in poster and the fallback if the video can't load.
    final video = slot.video;
    if (allowVideo && video != null) {
      image = SceneVideoLayer(
        assetKey: contentAssetKey(video),
        fit: fit,
        alignment: align,
        poster: image,
      );
    }

    if (opacity < 1) image = Opacity(opacity: opacity, child: image);
    return image;
  }
}

class _Vignette extends StatelessWidget {
  const _Vignette({this.light = false});

  /// [light] keeps the bottom translucent so the ridge foreground shows through
  /// (Home); the default grounds the bottom in near-black for reading surfaces.
  final bool light;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: light
              ? const <Color>[
                  Color(0x99060D0C),
                  Color(0x1A060D0C),
                  Color(0x00060D0C),
                  Color(0x00060D0C),
                  Color(0x40060D0C),
                ]
              : const <Color>[
                  Color(0x99060D0C),
                  Color(0x26060D0C),
                  Color(0x00060D0C),
                  Color(0xC7060D0C),
                  Color(0xFF060D0C),
                ],
          stops: light
              ? const <double>[0, 0.22, 0.42, 0.8, 1]
              : const <double>[0, 0.26, 0.46, 0.84, 1],
        ),
      ),
    );
  }
}
