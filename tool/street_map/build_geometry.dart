// Builds streets/<city>-streets.geojson from the APPROVED streets in
// content/streets/<city>.json and the cached OSM ways (M-A step 3).
//
// Output goes to <sources>/streets/ (default: sources/streets/, the local
// mirror of the long-ky-sources bucket) — it is GENERATED, never hand-edited,
// and reaches phones through the media pipeline (gen_media_manifest.dart
// copies .geojson as-is).
//
// Usage: dart run tool/street_map/build_geometry.dart [--city hcm]
//        [--out sources/streets/hcm-streets.geojson]

import 'dart:convert';
import 'dart:io';

import 'package:core_domain/core_domain.dart';

import 'common.dart';

void main(List<String> args) {
  String opt(String k, String d) {
    final i = args.indexOf(k);
    return i != -1 && i + 1 < args.length ? args[i + 1] : d;
  }

  final city = opt('--city', 'hcm');
  final outPath = opt('--out', 'sources/streets/$city-streets.geojson');
  final file = StreetMapFile.fromJson(
      jsonDecode(File('content/streets/$city.json').readAsStringSync())
          as Map<String, dynamic>);
  final ways = jsonDecode(waysCache(city).readAsStringSync()) as Map<String, dynamic>;
  final byKey = <String, List<List<GeoPt>>>{};
  ways.forEach((name, segs) {
    final key = normalizeName(name, stripStreetPrefix: true);
    for (final seg in segs as List) {
      (byKey[key] ??= []).add([
        for (final c in seg as List) GeoPt((c[0] as num).toDouble(), (c[1] as num).toDouble()),
      ]);
    }
  });

  final features = <Map<String, dynamic>>[];
  final missing = <String>[];
  for (final s in file.approved) {
    final segs = byKey[normalizeName(s.name, stripStreetPrefix: true)];
    if (segs == null) {
      missing.add(s.id);
      continue;
    }
    final lines = buildStreetLines(segs);
    features.add({
      'type': 'Feature',
      'properties': {'id': s.id},
      'geometry': {
        'type': 'MultiLineString',
        'coordinates': [
          for (final l in lines) [for (final p in l) [p.x, p.y]],
        ],
      },
    });
  }
  if (missing.isNotEmpty) {
    stderr.writeln('✗ approved streets with no OSM ways: ${missing.join(', ')}');
    exitCode = 1;
    return;
  }
  File(outPath).parent.createSync(recursive: true);
  // Compact (not canonical-pretty): this is a served artifact, size matters.
  File(outPath).writeAsStringSync(
      jsonEncode({'type': 'FeatureCollection', 'features': features}));
  stdout.writeln('✓ $outPath: ${features.length} streets, '
      '${File(outPath).lengthSync() ~/ 1024} KB');
}
