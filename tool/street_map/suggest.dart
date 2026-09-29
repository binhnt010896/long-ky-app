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
      ).toJson());

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

Future<void> _downloadWays(String city, File cache) async {
  final rings = readBoundaryRings(File('content/streets/$city-boundary.geojson'));
  final all = rings.expand((r) => r);
  final s = all.map((p) => p.y).reduce((a, b) => a < b ? a : b);
  final n = all.map((p) => p.y).reduce((a, b) => a > b ? a : b);
  final w = all.map((p) => p.x).reduce((a, b) => a < b ? a : b);
  final e = all.map((p) => p.x).reduce((a, b) => a > b ? a : b);
  final res = await overpass('[out:json][timeout:300][date:"$boundaryDate"];'
      'way["highway"]["name"]($s,$w,$n,$e);out geom;');
  final byName = <String, List<List<List<double>>>>{};
  for (final el in (res['elements'] as List).cast<Map<String, dynamic>>()) {
    final geom = (el['geometry'] as List?) ?? const [];
    if (geom.length < 2) continue;
    final mid = geom[geom.length ~/ 2];
    if (!pointInRings(
        GeoPt((mid['lon'] as num).toDouble(), (mid['lat'] as num).toDouble()), rings)) {
      continue;
    }
    final name = (el['tags'] as Map)['name'] as String;
    (byName[name] ??= []).add([
      for (final g in geom) [(g['lon'] as num).toDouble(), (g['lat'] as num).toDouble()],
    ]);
  }
  cache.parent.createSync(recursive: true);
  cache.writeAsStringSync(jsonEncode(byName));
  stdout.writeln('✓ ${cache.path}: ${byName.length} distinct names');
}
