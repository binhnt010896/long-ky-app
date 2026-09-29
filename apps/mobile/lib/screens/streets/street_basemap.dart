// ignore_for_file: implementation_imports
import 'package:vector_map_tiles_pmtiles/src/themes/v4/_package.dart' as v4;
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

/// The Protomaps PMTiles extract of old HCMC, hosted on `long-ky-content` R2
/// (decision M1). Override per build with `--dart-define=STREET_BASEMAP_URL=…`.
///
/// Empty by default until the extract is uploaded: the screen then shows the
/// plain lacquer ground with the gold streets, which is a complete (if
/// sparse) map rather than a broken one.
const String kStreetBasemapUrl =
    String.fromEnvironment('STREET_BASEMAP_URL', defaultValue: '');

/// Layers dropped from the Protomaps dark theme:
///  - `water_label_ocean` — sovereignty guard: no sea/ocean labels;
///  - `boundaries_country` — national borders are not this map's business;
///  - `pois` — needs the sprite sheet, and would compete with the gold streets.
const Set<String> kHiddenBasemapLayers = {
  'water_label_ocean',
  'boundaries_country',
  'pois',
};

/// The Protomaps v4 dark layers minus [kHiddenBasemapLayers].
List<Map<String, Object>> streetBasemapLayers() => [
      for (final l in v4.themeDark)
        if (!kHiddenBasemapLayers.contains(l['id'])) l,
    ];

/// The vector theme for the basemap (dark ground, muted roads, so the gold
/// history streets stand out).
vtr.Theme buildStreetBasemapTheme() =>
    const ProtomapsThemes().build(streetBasemapLayers());
