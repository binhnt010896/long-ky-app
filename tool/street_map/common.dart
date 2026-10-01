// Shared plumbing for the Cycle M street tools: an Overpass client with
// mirror fallback, polygon helpers, and content loading.
//
// Network note: Overpass is the only external dependency. Everything else in
// tool/street_map/ works offline from the files it writes.

import 'dart:convert';
import 'dart:io';

import 'package:core_domain/core_domain.dart';

const overpassMirrors = <String>[
  'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
  'https://overpass-api.de/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
  'https://overpass.private.coffee/api/interpreter',
];

/// The date the old (pre-merger) HCMC territory is read as of.
const boundaryDate = '2025-06-01T00:00:00Z';

/// Runs [query] against the mirrors, three rounds with growing pauses. Throws
/// only when every mirror failed in every round.
Future<Map<String, dynamic>> overpass(String query) async {
  Object? last;
  for (var round = 0; round < 3; round++) {
    if (round > 0) await Future<void>.delayed(Duration(seconds: 20 * round));
    for (final url in overpassMirrors) {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
      try {
        final req = await client.postUrl(Uri.parse(url));
        req.headers.contentType =
            ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
        req.headers.set('User-Agent', 'long-ky-app street tool (binhnt.010896@gmail.com)');
        req.write('data=${Uri.encodeQueryComponent(query)}');
        final res = await req.close().timeout(const Duration(seconds: 200));
        final body = await res.transform(utf8.decoder).join();
        if (res.statusCode == 200) {
          final json = jsonDecode(body) as Map<String, dynamic>;
          // Overpass reports a server-side timeout as 200 + a remark.
          if (json['remark'] is String &&
              (json['remark'] as String).contains('runtime error')) {
            last = json['remark'];
            continue;
          }
          return json;
        }
        last = 'HTTP ${res.statusCode} from $url';
      } catch (e) {
        last = '$e ($url)';
      } finally {
        client.close();
      }
    }
  }
  throw StateError('all Overpass mirrors failed; last: $last');
}

/// Reads the rings out of `content/streets/<city>-boundary.geojson`
/// (Polygon or MultiPolygon, first feature).
List<List<GeoPt>> readBoundaryRings(File f) {
  final json = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  final geom = (json['type'] == 'FeatureCollection'
      ? (json['features'] as List).first['geometry']
      : json['type'] == 'Feature'
          ? json['geometry']
          : json) as Map<String, dynamic>;
  final polys = geom['type'] == 'Polygon'
      ? <List<dynamic>>[geom['coordinates'] as List<dynamic>]
      : (geom['coordinates'] as List<dynamic>).cast<List<dynamic>>();
  return [
    for (final poly in polys)
      for (final ring in poly)
        [
          for (final c in ring as List)
            GeoPt((c[0] as num).toDouble(), (c[1] as num).toDouble()),
        ],
  ];
}

({List<Map<String, dynamic>> people, List<Map<String, dynamic>> eras}) loadContent() {
  final people = ((jsonDecode(File('content/people.json').readAsStringSync())
          as Map<String, dynamic>)['people'] as List)
      .cast<Map<String, dynamic>>();
  // Eras list their events as {ref}s into content/events.json (Cycle N); the
  // matcher reads event titles, so hand it eras with the events inlined.
  final events = eventJsonById(
      jsonDecode(File('content/events.json').readAsStringSync()) as Map<String, dynamic>);
  final eras = [
    for (final f in Directory('content/eras').listSync().whereType<File>())
      if (f.path.endsWith('.json'))
        inlineEraEvents(
            jsonDecode(f.readAsStringSync()) as Map<String, dynamic>, events),
  ];
  return (people: people, eras: eras);
}

/// Writes canonical JSON (same formatter the rest of content/ uses).
void writeCanonical(String path, Object data) =>
    File(path).writeAsStringSync(ContentFormatter.format(data));

/// Cached raw Overpass ways so suggest/build_geometry don't re-download:
/// `build/streets/<city>-ways.json` = {name: [[[lng,lat],...], ...]}.
File waysCache(String city) => File('build/streets/$city-ways.json');
