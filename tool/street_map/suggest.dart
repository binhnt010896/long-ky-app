// Suggests street → person/event/era matches for one city (M-A step 2).
//
// 1. Downloads named highway=* ways inside the boundary bbox (Overpass) into
//    build/streets/<city>-ways.json, keeping only ways whose midpoint is in
//    the boundary polygon. `--offline` reuses that cache.
// 2. Matches names against content/ + content/streets/aliases.json.
// 3. Merges into content/streets/<city>.json. Only `exact` matches are
//    auto-approved; a re-run never un-approves or edits an existing entry.
// 4. Prints the M3 review table: everything still `suggested`.
//
// Usage: dart run tool/street_map/suggest.dart [--city hcm] [--offline]

import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';

import 'package:core_domain/core_domain.dart';

import 'common.dart';

Future<void> main(List<String> args) async {
  final i = args.indexOf('--city');
  final city = i != -1 ? args[i + 1] : 'hcm';
  final offline = args.contains('--offline');

  final cache = waysCache(city);
  if (!offline || !cache.existsSync()) {
    await _downloadWays(city, cache);
  }
  final ways = (jsonDecode(cache.readAsStringSync()) as Map<String, dynamic>);

  final content = loadContent();
  final aliasFile = File('content/streets/aliases.json');
  final aliases = aliasFile.existsSync()
      ? ((jsonDecode(aliasFile.readAsStringSync()) as Map<String, dynamic>)['aliases']
              as List)
          .cast<Map<String, dynamic>>()
      : <Map<String, dynamic>>[];
  final matcher = StreetMatcher.fromContent(
      people: content.people, eras: content.eras, aliases: aliases);
  final suggested = matcher.suggest(ways.keys);

  final out = File('content/streets/$city.json');
  final existing = out.existsSync()
      ? StreetMapFile.fromJson(jsonDecode(out.readAsStringSync()) as Map<String, dynamic>)
      : StreetMapFile(city: city, osmSnapshot: '', streets: const []);
  final merged = StreetMatcher.merge(existing.streets, suggested);
  writeCanonical(
      out.path,
      StreetMapFile(
        city: city,
        osmSnapshot: DateTime.now().toUtc().toIso8601String().substring(0, 10),
        streets: merged,
        geometry: existing.geometry.isEmpty
            ? 'streets/$city-streets.geojson'
            : existing.geometry,
        // The base map is hand-set (tool/street_map/ has no step that makes it
        // in this file), so a re-run must carry it over, never drop it.
        basemap: existing.basemap,
        // Likewise hand-written (Cycle P): the landmarks and the opening view.
        landmarks: existing.landmarks,
        start: existing.start,
      ).toJson());

  _printCoverage(ways, merged);

  final pending = merged.where((s) => !s.isApproved).toList();
  stdout.writeln('✓ ${out.path}: ${merged.length} streets, '
      '${merged.length - pending.length} approved, ${pending.length} awaiting review');
  if (pending.isNotEmpty) {
    stdout.writeln('\n── M3 review table ──');
    for (final s in pending) {
      stdout.writeln('${s.id.padRight(28)} ${s.reason.padRight(6)} '
          '${s.targets.map((t) => '${t.type.name}:${t.id}@${t.era}').join(' | ')}');
    }
    stdout.writeln('\nSet "status": "approved" in $out for the ones you accept.');
  }
}

/// Prints how much of the city's named streets the APPROVED mapping covers —
/// by count and by length — so each wave of content shows its gain (Cycle R).
/// Counts only names without digits, so "Hẻm 12" and "Đường số 5" don't drown
/// out the history-named streets.
void _printCoverage(Map<String, dynamic> ways, List<MappedStreet> streets) {
  double km(Object? lines) {
    var total = 0.0;
    for (final line in lines as List<dynamic>) {
      final pts = (line as List<dynamic>).cast<List<dynamic>>();
      for (var i = 1; i < pts.length; i++) {
        final dx = ((pts[i][0] as num) - (pts[i - 1][0] as num)) * 109.3;
        final dy = ((pts[i][1] as num) - (pts[i - 1][1] as num)) * 110.6;
        total += math.sqrt(dx * dx + dy * dy);
      }
    }
    return total;
  }

  final approved = {
    for (final s in streets)
      if (s.isApproved) normalizeName(s.name),
  };
  var allCount = 0, hitCount = 0;
  var allKm = 0.0, hitKm = 0.0;
  ways.forEach((name, lines) {
    if (RegExp(r'\d').hasMatch(name)) return;
    final l = km(lines);
    allCount++;
    allKm += l;
    if (approved.contains(normalizeName(name))) {
      hitCount++;
      hitKm += l;
    }
  });
  stdout.writeln('  coverage: $hitCount of $allCount named streets '
      '(${(100 * hitCount / allCount).toStringAsFixed(1)} %), '
      '${hitKm.toStringAsFixed(0)} of ${allKm.toStringAsFixed(0)} km '
      '(${(100 * hitKm / allKm).toStringAsFixed(1)} %)');
}

Future<void> _downloadWays(String city, File cache) async {
  final rings = readBoundaryRings(File('content/streets/$city-boundary.geojson'));
  final all = rings.expand((r) => r);
  final s = all.map((p) => p.y).reduce((a, b) => a < b ? a : b);
  final n = all.map((p) => p.y).reduce((a, b) => a > b ? a : b);
  final w = all.map((p) => p.x).reduce((a, b) => a < b ? a : b);
  final e = all.map((p) => p.x).reduce((a, b) => a > b ? a : b);
  // Tiled and RESUMABLE: one bbox-wide query times out on the public mirrors,
  // and a long run must survive a bad mirror. Each tile is cached in
  // build/streets/tiles/; a tile that keeps failing is split into quarters.
  // Street NAMES don't change with the July-2025 merger, and the boundary
  // polygon (an as-of-2025-06-01 read) decides territory, so this reads
  // current data. Only road classes that carry street names.
  const step = 0.1;
  final byName = <String, List<List<List<double>>>>{};
  final seenWays = <int>{};

  bool touchesBoundary(double x, double y, double x2, double y2) {
    final probe = [
      GeoPt(x, y), GeoPt(x2, y), GeoPt(x, y2), GeoPt(x2, y2),
      GeoPt((x + x2) / 2, (y + y2) / 2),
    ];
    return probe.any((p) => pointInRings(p, rings)) ||
        rings.expand((r) => r).any((p) => p.x >= x && p.x <= x2 && p.y >= y && p.y <= y2);
  }

  Future<List<Map<String, dynamic>>> tile(
      double x, double y, double x2, double y2, int depth) async {
    final f = File('build/streets/tiles/${x.toStringAsFixed(5)}_${y.toStringAsFixed(5)}_'
        '${x2.toStringAsFixed(5)}_${y2.toStringAsFixed(5)}.json');
    if (f.existsSync()) {
      return (jsonDecode(f.readAsStringSync()) as List).cast<Map<String, dynamic>>();
    }
    List<Map<String, dynamic>> els;
    try {
      final res = await overpass('[out:json][timeout:120];'
          'way["highway"~"^($_roads)\$"]["name"]($y,$x,$y2,$x2);out geom tags;');
      els = (res['elements'] as List).cast<Map<String, dynamic>>();
    } on StateError {
      if (depth >= 3) rethrow;
      stdout.writeln('  splitting tile ($x,$y) — depth ${depth + 1}');
      final mx = (x + x2) / 2, my = (y + y2) / 2;
      els = [
        for (final q in [(x, y, mx, my), (mx, y, x2, my), (x, my, mx, y2), (mx, my, x2, y2)])
          ...await tile(q.$1, q.$2, q.$3, q.$4, depth + 1),
      ];
    }
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(jsonEncode(els));
    return els;
  }

  for (var y = s; y < n; y += step) {
    for (var x = w; x < e; x += step) {
      final y2 = y + step > n ? n : y + step;
      final x2 = x + step > e ? e : x + step;
      if (!touchesBoundary(x, y, x2, y2)) continue;
      for (final el in await tile(x, y, x2, y2, 0)) {
        if (!seenWays.add(el['id'] as int)) continue;
        final geom = (el['geometry'] as List?) ?? const [];
        if (geom.length < 2) continue;
        final mid = geom[geom.length ~/ 2];
        if (!pointInRings(
            GeoPt((mid['lon'] as num).toDouble(), (mid['lat'] as num).toDouble()),
            rings)) {
          continue;
        }
        final name = (el['tags'] as Map)['name'] as String;
        (byName[name] ??= []).add([
          for (final g in geom)
            [(g['lon'] as num).toDouble(), (g['lat'] as num).toDouble()],
        ]);
      }
      stdout.writeln('  tile ($x,$y): ${byName.length} names so far');
    }
  }
  cache.parent.createSync(recursive: true);
  cache.writeAsStringSync(jsonEncode(byName));
  stdout.writeln('✓ ${cache.path}: ${byName.length} distinct names');
}

const _roads = 'motorway|trunk|primary|secondary|tertiary|unclassified|'
    'residential|living_street|service|pedestrian|'
    'motorway_link|trunk_link|primary_link|secondary_link|tertiary_link';
