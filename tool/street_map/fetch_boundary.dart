// Fetches the OLD (pre-July-2025) HCMC administrative boundary from Overpass
// with an "attic" query and writes content/streets/hcm-boundary.geojson.
//
// Usage: dart run tool/street_map/fetch_boundary.dart [--city hcm]
//        [--name "Thành phố Hồ Chí Minh"]
//
// Fallback if Overpass attic data is unusable: geoBoundaries' pre-2025 ADM1
// polygon (coarse — 115 points near the Dĩ An/Thuận An edge).

import 'dart:io';

import 'package:core_domain/core_domain.dart';

import 'common.dart';

Future<void> main(List<String> args) async {
  String opt(String k, String d) {
    final i = args.indexOf(k);
    return i != -1 && i + 1 < args.length ? args[i + 1] : d;
  }

  final city = opt('--city', 'hcm');
  final name = opt('--name', 'Thành phố Hồ Chí Minh');
  final q = '[out:json][timeout:180][date:"$boundaryDate"];'
      'relation["boundary"="administrative"]["admin_level"="4"]["name"="$name"];'
      'out geom;';
  final res = await overpass(q);
  final rels = (res['elements'] as List).cast<Map<String, dynamic>>();
  if (rels.isEmpty) {
    stderr.writeln('✗ no relation named "$name" at $boundaryDate');
    exitCode = 1;
    return;
  }
  final members = (rels.first['members'] as List)
      .cast<Map<String, dynamic>>()
      .where((m) => m['type'] == 'way' && m['role'] == 'outer' && m['geometry'] != null);
  final segments = [
    for (final m in members)
      [
        for (final g in m['geometry'] as List)
          GeoPt((g['lon'] as num).toDouble(), (g['lat'] as num).toDouble()),
      ],
  ];
  // Outer ways come in pieces; chain them into closed rings.
  final rings = chainSegments(segments)
      .where((r) => r.length > 3 && r.first == r.last)
      .toList();
  if (rings.isEmpty) {
    stderr.writeln('✗ could not close any boundary ring (${segments.length} ways)');
    exitCode = 1;
    return;
  }
  Directory('content/streets').createSync(recursive: true);
  writeCanonical('content/streets/$city-boundary.geojson', {
    'type': 'Feature',
    'properties': {'name': name, 'asOf': boundaryDate},
    'geometry': {
      'type': 'MultiPolygon',
      'coordinates': [
        for (final r in rings)
          [
            [
              for (final p in simplifyLine(r, 20))
                [roundCoord(p.x), roundCoord(p.y)],
            ],
          ],
      ],
    },
  });
  stdout.writeln('✓ content/streets/$city-boundary.geojson (${rings.length} ring(s))');
}
