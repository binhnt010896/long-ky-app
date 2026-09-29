import 'dart:convert';

import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../theme/content_assets.dart';

/// Everything the street map needs, loaded once.
class StreetMapData {
  const StreetMapData({
    required this.file,
    required this.lines,
    required this.boundary,
    required this.bounds,
  });

  /// The mapping (`content/streets/hcm.json`): street → what it's named for.
  final StreetMapFile file;

  /// Approved streets only → their polylines, from the generated GeoJSON.
  final Map<String, List<List<LatLng>>> lines;

  /// The old-HCMC boundary rings (drives the outside-mask).
  final List<List<LatLng>> boundary;

  /// The camera lock: the boundary's bbox plus a small margin. The map can
  /// never be panned outside this, so open sea and island chains never show.
  final LatLngBounds bounds;

  MappedStreet? street(String id) {
    for (final s in file.streets) {
      if (s.id == id) return s;
    }
    return null;
  }
}

/// Where the street map's data comes from — a seam so widget tests never
/// touch the bundle or the network.
abstract class StreetDataSource {
  /// The mapping only (cheap; used by the reverse chip on detail pages).
  /// Null when the city has no street map yet.
  Future<StreetMapFile?> loadMapping();

  Future<StreetMapData?> loadAll();
}

/// Margin around the boundary bbox, in degrees (~5 km).
const double kStreetBoundsMargin = 0.05;

/// The bundled mapping + boundary (`assets/content/streets/`), and the
/// street GeoJSON from the media CDN (it is a media file, like era art).
class BundledStreetDataSource implements StreetDataSource {
  const BundledStreetDataSource({this.city = 'hcm'});

  final String city;

  @override
  Future<StreetMapFile?> loadMapping() async {
    try {
      final raw = await rootBundle.loadString('assets/content/streets/$city.json');
      return StreetMapFile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<StreetMapData?> loadAll() async {
    final file = await loadMapping();
    if (file == null || file.geometry.isEmpty) return null;
    try {
      final boundaryRaw =
          await rootBundle.loadString('assets/content/streets/$city-boundary.geojson');
      final url = ContentMedia.url(file.geometry);
      // On device the shared media cache keeps it offline-capable; the web
      // preview has no file cache, so it fetches directly.
      final geoJson = kIsWeb
          ? await http.read(Uri.parse(url))
          : await (await ContentMedia.cache.getSingleFile(url)).readAsString();
      return parseStreetMapData(
        file: file,
        boundaryGeoJson: boundaryRaw,
        streetsGeoJson: geoJson,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Pure parse step (unit-tested): the two GeoJSON documents → [StreetMapData].
/// Only APPROVED streets are kept.
StreetMapData parseStreetMapData({
  required StreetMapFile file,
  required String boundaryGeoJson,
  required String streetsGeoJson,
}) {
  final approved = {for (final s in file.approved) s.id};
  final lines = <String, List<List<LatLng>>>{};
  final features = (jsonDecode(streetsGeoJson) as Map<String, dynamic>)['features'] as List;
  for (final f in features) {
    final m = f as Map<String, dynamic>;
    final id = (m['properties'] as Map<String, dynamic>)['id'] as String;
    if (!approved.contains(id)) continue;
    final geom = m['geometry'] as Map<String, dynamic>;
    final coords = geom['type'] == 'LineString'
        ? <dynamic>[geom['coordinates']]
        : geom['coordinates'] as List;
    lines[id] = [
      for (final line in coords)
        [
          for (final c in line as List)
            LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
        ],
    ];
  }

  final boundary = _boundaryRings(jsonDecode(boundaryGeoJson) as Map<String, dynamic>);
  if (boundary.isEmpty) throw const FormatException('empty boundary');
  var s = 90.0, n = -90.0, w = 180.0, e = -180.0;
  for (final ring in boundary) {
    for (final p in ring) {
      if (p.latitude < s) s = p.latitude;
      if (p.latitude > n) n = p.latitude;
      if (p.longitude < w) w = p.longitude;
      if (p.longitude > e) e = p.longitude;
    }
  }
  return StreetMapData(
    file: file,
    lines: lines,
    boundary: boundary,
    bounds: LatLngBounds(
      LatLng(s - kStreetBoundsMargin, w - kStreetBoundsMargin),
      LatLng(n + kStreetBoundsMargin, e + kStreetBoundsMargin),
    ),
  );
}

List<List<LatLng>> _boundaryRings(Map<String, dynamic> json) {
  final geom = (json['type'] == 'FeatureCollection'
      ? (json['features'] as List).first['geometry']
      : json['type'] == 'Feature'
          ? json['geometry']
          : json) as Map<String, dynamic>;
  final polys = geom['type'] == 'Polygon'
      ? <dynamic>[geom['coordinates']]
      : geom['coordinates'] as List<dynamic>;
  return [
    for (final poly in polys)
      for (final ring in poly as List)
        [
          for (final c in ring as List)
            LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
        ],
  ];
}

final streetDataSourceProvider =
    Provider<StreetDataSource>((ref) => const BundledStreetDataSource());

/// The mapping alone — cheap, so detail pages can ask "is this a street?".
final streetMappingProvider = FutureProvider<StreetMapFile?>(
    (ref) => ref.watch(streetDataSourceProvider).loadMapping());

/// The full street map data (mapping + geometry + boundary).
final streetMapDataProvider = FutureProvider<StreetMapData?>(
    (ref) => ref.watch(streetDataSourceProvider).loadAll());
