/// The immersive layer's primitives for Việt Sử.
///
/// [ExperienceTier] + [TierCapabilities] are the single axis the widget tree
/// branches on (never `Platform`). [ParallaxScene] is the depth primitive, fed a
/// normalized pointer by a [ParallaxController] — from device tilt on flagship
/// ([TiltParallaxDriver]) or held at rest on reduced/trailer.
library;

export 'src/experience_tier.dart';
export 'src/parallax_controller.dart';
export 'src/parallax_scene.dart';
