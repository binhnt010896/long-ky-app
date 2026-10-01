// ignore_for_file: implementation_imports
import 'package:core_domain/core_domain.dart';
import 'package:vector_map_tiles_pmtiles/src/themes/v4/_package.dart' as v4;
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import '../../theme/content_assets.dart';

/// A build-time override of the base map's address
/// (`--dart-define=STREET_BASEMAP_URL=…`) — for trying another extract locally.
/// Empty in a normal build: see [streetBasemapUrl].
const String kStreetBasemapUrl =
    String.fromEnvironment('STREET_BASEMAP_URL', defaultValue: '');

/// Where the base map comes from (Cycle O, decisions M1/O1): the Protomaps
/// PMTiles extract of old HCMC, hosted on the media CDN like the street
/// geometry and era art, so a refreshed map ships with a *publish* — its
/// version changes in the media manifest — not with an app update.
///
/// [override] (the dart-define) wins; otherwise the mapping's `basemap` media
/// path is resolved through [mediaUrl]. Empty = no base map: the screen shows
/// the plain lacquer ground with the gold streets, a complete if sparse map
/// rather than a broken one.
String streetBasemapUrl(
  StreetMapFile file, {
  String override = kStreetBasemapUrl,
  String Function(String path) mediaUrl = ContentMedia.url,
}) {
  if (override.isNotEmpty) return override;
  if (file.basemap.isEmpty) return '';
  return mediaUrl(file.basemap);
}

/// Layers dropped from the Protomaps dark theme:
///  - `water_label_ocean` — sovereignty guard: no sea/ocean labels;
///  - `boundaries_country` — national borders are not this map's business;
///  - `pois` — needs the sprite sheet, and would compete with the gold streets.
const Set<String> kHiddenBasemapLayers = {
  'water_label_ocean',
  'boundaries_country',
  'pois',
};

/// What a label shows: the place's own name, which in Vietnam is Vietnamese
/// (decision O4). The theme's own `text-field` is a long expression (`format`,
/// `is-supported-script`, per-script fonts) that `vector_tile_renderer` does
/// not understand — it drops the whole text, so every label in the stock theme
/// silently vanished. A plain `get` it does understand.
const List<Object> kBasemapLabelField = ['get', 'name'];

/// The Protomaps v4 dark layers minus [kHiddenBasemapLayers], with every label
/// layer's text set to [kBasemapLabelField].
List<Map<String, Object>> streetBasemapLayers() => [
      for (final l in v4.themeDark)
        if (!kHiddenBasemapLayers.contains(l['id'])) _withPlainLabels(l),
    ];

Map<String, Object> _withPlainLabels(Map<String, Object> layer) {
  final layout = layer['layout'];
  if (layer['type'] != 'symbol' || layout is! Map || !layout.containsKey('text-field')) {
    return layer;
  }
  return {
    ...layer,
    'layout': {...layout, 'text-field': kBasemapLabelField},
  };
}

/// The vector theme for the basemap (dark ground, muted roads, so the gold
/// history streets stand out). [logger] reports what the renderer could not
/// understand in the theme.
vtr.Theme buildStreetBasemapTheme({vtr.Logger? logger}) =>
    ProtomapsThemes(logger: logger).build(streetBasemapLayers());
