import 'package:core_domain/core_domain.dart';
import 'package:ui_kit/ui_kit.dart';

/// Bridge content colour (hex strings from JSON) to the ui_kit sơn mài palette.
///
/// The accent derives a coherent scene; an explicit `scene` list in content
/// overrides the derived gradient stop-for-stop, and an explicit particle colour
/// overrides the derived one.
VSEraPalette paletteForEra(Era era) {
  final p = era.palette;
  var palette = VSEraPalette.fromAccent(
    era.slug,
    p.accent,
    particle: p.particle == null ? null : VSColors.fromHex(p.particle!),
  );
  final scene = p.scene;
  if (scene != null && scene.length >= 2) {
    palette = palette.copyWith(
      sceneStops: scene.map(VSColors.fromHex).toList(),
    );
  }
  return palette;
}
