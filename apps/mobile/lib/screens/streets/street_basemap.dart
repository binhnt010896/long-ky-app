// ignore_for_file: implementation_imports
import 'dart:io' show Directory;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pmtiles/pmtiles.dart' show HttpAt, PmTilesArchive, ReadAt, ZXY;
import 'package:vector_map_tiles_pmtiles/src/themes/v4/_package.dart' as v4;
import 'package:vector_map_tiles/vector_map_tiles.dart' show TileProviders, VectorTileProvider;
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import '../../theme/content_assets.dart';
import 'street_data.dart';
import 'street_perf.dart';

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
///  - `pois` — needs the sprite sheet, and would compete with the gold streets;
///  - `places_subplace` — "Khu phố 9", "Ấp 37"…: dozens of neighbourhood
///    labels that tell a reader nothing and bury the ones that do.
const Set<String> kHiddenBasemapLayers = {
  'water_label_ocean',
  'boundaries_country',
  'pois',
  'places_subplace',
};

/// Per-layer minimum zoom, overriding the theme's: side-street names only
/// once the reader is close enough to need them (the theme says 15).
const Map<String, int> kBasemapLabelMinZoom = {
  'roads_labels_minor': 16,
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
  final minZoom = kBasemapLabelMinZoom[layer['id']];
  return {
    ...layer,
    if (minZoom != null) 'minzoom': minZoom,
    'layout': {...layout, 'text-field': kBasemapLabelField},
  };
}

/// The vector theme for the basemap (dark ground, muted roads, so the gold
/// history streets stand out). [logger] reports what the renderer could not
/// understand in the theme.
vtr.Theme buildStreetBasemapTheme({vtr.Logger? logger}) =>
    ProtomapsThemes(logger: logger).build(streetBasemapLayers());

/// The on-disk tile cache's folder name. Not the library's default
/// (`.vector_map`): that one holds tiles cached while the labels were still
/// being dropped, and the cache keeps tiles for weeks — a phone that had
/// visited the map would have stayed label-less. **Bump the suffix whenever
/// the theme changes in a way cached tiles must not outlive.** The base map's
/// own version (`?v=` in its address) is added by [basemapCacheFolderFor], so a
/// republished extract starts a fresh cache by itself. (Never called on web:
/// no disk there.)
const String kBasemapCacheFolder = '.long_ky_basemap_v3';

/// How long a cached tile is trusted. The folder is versioned per extract, so
/// a long time-to-live never serves a stale map.
const Duration kBasemapTileTtl = Duration(days: 90);

/// Tiles fetched at once. The package default (4) leaves the connection idle
/// between small range requests; 8 fills it without flooding the CDN.
const int kBasemapConcurrency = 8;

/// The folder's name for the base map at [url]: [kBasemapCacheFolder], plus the
/// extract's version when the address carries one.
String basemapCacheName(String url) {
  final v = Uri.tryParse(url)?.queryParameters['v'] ?? '';
  return v.isEmpty ? kBasemapCacheFolder : '${kBasemapCacheFolder}_$v';
}

/// The cache folder for the base map at [url]: under the app *support*
/// directory (Android may empty the temp directory at any time, which turned a
/// return visit into a first one), named for the extract's version.
Future<Directory> Function() basemapCacheFolderFor(String url) {
  final name = basemapCacheName(url);
  return () async =>
      Directory('${(await getApplicationSupportDirectory()).path}/$name');
}

/// A [ReadAt] that remembers what it has read (by offset and length) and joins
/// identical reads in flight. The base map is one big file read in small ranges,
/// one per tile: with this in front of the HTTP reader, tiles fetched ahead of
/// time at the splash are answered from memory when the map screen asks for them.
/// Bounded ([maxBytes]); the oldest reads are forgotten first.
class CachingReadAt implements ReadAt {
  CachingReadAt(this._inner, {this.maxBytes = 12 * 1024 * 1024});

  final ReadAt _inner;
  final int maxBytes;
  final Map<(int, int), Uint8List> _done = <(int, int), Uint8List>{};
  final Map<(int, int), Future<Uint8List>> _inFlight = <(int, int), Future<Uint8List>>{};
  int _bytes = 0;

  /// Bytes held right now (for tests).
  int get cachedBytes => _bytes;

  @override
  Future<http.ByteStream> readAt(int offset, int length) async {
    final key = (offset, length);
    final hit = _done[key];
    if (hit != null) return http.ByteStream.fromBytes(hit);
    final data = await (_inFlight[key] ??= _load(key));
    return http.ByteStream.fromBytes(data);
  }

  Future<Uint8List> _load((int, int) key) async {
    try {
      final stream = await _inner.readAt(key.$1, key.$2);
      final data = await stream.toBytes();
      _done[key] = data;
      _bytes += data.length;
      // Insertion order is oldest-first, so trimming from the front drops the oldest.
      while (_bytes > maxBytes && _done.length > 1) {
        final oldest = _done.keys.first;
        _bytes -= _done.remove(oldest)!.length;
      }
      return data;
    } finally {
      _inFlight.remove(key);
    }
  }

  @override
  Future<void> close() => _inner.close();
}

/// The tiles a phone shows when the map first opens at ([lat], [lng], [zoom]):
/// a block around the centre, [across] wide by [down] tall (the camera is
/// centred, so the block is too). Pure, for tests.
List<ZXY> startViewTiles(double lat, double lng, double zoom,
    {int across = 5, int down = 7}) {
  final z = zoom.floor();
  final n = 1 << z;
  final x = ((lng + 180) / 360 * n).floor();
  final rad = lat * math.pi / 180;
  final y = ((1 - math.log(math.tan(rad) + 1 / math.cos(rad)) / math.pi) / 2 * n).floor();
  return <ZXY>[
    for (var dy = -(down ~/ 2); dy <= down ~/ 2; dy++)
      for (var dx = -(across ~/ 2); dx <= across ~/ 2; dx++)
        if (x + dx >= 0 && x + dx < n && y + dy >= 0 && y + dy < n)
          ZXY(z, x + dx, y + dy),
  ];
}

/// The base map opened once: the PMTiles archive (header + directories are the
/// slow part), the provider map the vector layer is handed, and its cache
/// folder. All three must keep their identity for the layer to finish a paint,
/// so they live here, not in a widget's build.
class StreetBasemap {
  StreetBasemap(this.url, this.archive, PmTilesVectorTileProvider provider)
      : providers = TileProviders(
            <String, VectorTileProvider>{'protomaps': TimedTileProvider(provider)}),
        cacheFolder = basemapCacheFolderFor(url);

  final String url;
  final PmTilesArchive archive;

  /// Reads [tiles] now (a few at a time) so the reads are already in memory when
  /// the map asks for them. Fire and forget: failures are swallowed, since the
  /// map fetches whatever it needs itself, just later.
  Future<void> prefetch(Iterable<ZXY> tiles, {int concurrency = 6}) async {
    final queue = tiles.toList();
    var next = 0;
    Future<void> worker() async {
      while (next < queue.length) {
        final t = queue[next++];
        try {
          await archive.tile(t.toTileId());
        } catch (_) {
          // A tile that will not load now is just loaded later.
        }
      }
    }

    await Future.wait(<Future<void>>[for (var i = 0; i < concurrency; i++) worker()]);
  }

  final TileProviders providers;
  final Future<Directory> Function() cacheFolder;
}

/// The base map, opened on first read and kept for the whole app run. The
/// splash reads it in the background (see `SplashGate`), so by the time the
/// street screen opens the archive is already open. Null = no base map for
/// this city (the plain ground), or it could not be opened.
http.Client _client() => http.Client();

final streetBasemapProvider = FutureProvider<StreetBasemap?>((ref) async {
  final file = await ref.watch(streetMappingProvider.future);
  if (file == null) return null;
  final url = streetBasemapUrl(file);
  if (url.isEmpty) return null;
  try {
    final http = url.startsWith('http://') || url.startsWith('https://');
    final archive = http
        ? await PmTilesArchive.fromReadAt(
            CachingReadAt(HttpAt(_client(), Uri.parse(url))))
        : await PmTilesArchive.from(url);
    StreetPerf.instance.mark('archive_open');
    return StreetBasemap(url, archive,
        PmTilesVectorTileProvider.fromArchive(archive));
  } catch (_) {
    // The map still works without a base map.
    return null;
  }
});
