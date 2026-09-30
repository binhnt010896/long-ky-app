// One-shot migration (Cycle N): moves every event out of content/eras/*.json
// into content/events.json and replaces each era's `events` with
// `[{"ref": "<id>"}, …]` in reading order, dropping the per-event `order`
// (the list position is the order from now on).
//
// It verifies itself before writing anything: re-inlining every migrated era
// must reproduce the original era exactly (same values, same event order, the
// same `order` numbers). It reports how many eras come back byte-identical
// too — `order` is re-inserted right before `kind`, where every authored
// event keeps it, so all but a hand-edited outlier should.
//
// Already-migrated eras (no inline events) are left alone, so a second run
// is a no-op. The script is committed for the record.
//
// Usage: dart run tool/migrate_events.dart [--dry-run]

import 'dart:convert';
import 'dart:io';

import 'package:core_domain/core_domain.dart';

Future<void> main(List<String> args) async {
  exitCode = _run(dryRun: args.contains('--dry-run'));
}

int _run({required bool dryRun}) {
  final content = Directory('${Directory.current.path}/content');
  final index = jsonDecode(File('${content.path}/index.json').readAsStringSync())
      as Map<String, dynamic>;
  final slugs = (index['eras'] as List).cast<String>();
  final eventsFile = File('${content.path}/events.json');

  final registry = <Map<String, dynamic>>[];
  final seenIds = <String>{};
  final newEras = <String, Map<String, dynamic>>{};
  final originals = <String, Map<String, dynamic>>{};
  var migrated = 0;

  for (final slug in slugs) {
    final file = File('${content.path}/eras/$slug.json');
    final era = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final events =
        (era['events'] as List).cast<Map<String, dynamic>>();
    if (events.every(isEventRef)) continue; // already migrated

    if (events.any(isEventRef)) {
      stderr.writeln('✗ $slug mixes inline events and refs — fix by hand');
      return 1;
    }
    final sorted = [...events]
      ..sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));
    for (var i = 0; i < sorted.length; i++) {
      if (sorted[i]['order'] != i) {
        stderr.writeln('✗ $slug: order is not a contiguous 0..n-1 run');
        return 1;
      }
      final id = sorted[i]['id'] as String;
      if (!seenIds.add(id)) {
        stderr.writeln('✗ event id "$id" appears twice');
        return 1;
      }
      registry.add(<String, dynamic>{
        for (final e in sorted[i].entries)
          if (e.key != 'order') e.key: e.value,
      });
    }
    originals[slug] = <String, dynamic>{...era, 'events': sorted};
    newEras[slug] = <String, dynamic>{
      ...era,
      'events': [
        for (final e in sorted) <String, dynamic>{'ref': e['id']},
      ],
    };
    migrated++;
  }

  if (migrated == 0) {
    stdout.writeln('✓ already migrated — nothing to do');
    return 0;
  }
  if (eventsFile.existsSync()) {
    stderr.writeln('✗ content/events.json already exists but some eras still '
        'inline events — refusing to merge by guesswork');
    return 1;
  }

  // Verify: re-inline and compare with the originals, value for value.
  final byId = <String, Map<String, dynamic>>{
    for (final e in registry) e['id'] as String: e,
  };
  var byteIdentical = 0;
  for (final slug in newEras.keys) {
    final back = inlineEraEvents(newEras[slug]!, byId);
    final want = originals[slug]!;
    if (jsonEncode(_canonical(back)) != jsonEncode(_canonical(want))) {
      stderr.writeln('✗ $slug does not round-trip — nothing written');
      return 1;
    }
    if (ContentFormatter.format(back) == ContentFormatter.format(want)) {
      byteIdentical++;
    }
  }
  stdout.writeln('✓ ${registry.length} events from $migrated eras; every era '
      'round-trips ($byteIdentical byte-identical)');

  if (dryRun) {
    stdout.writeln('(dry run — nothing written)');
    return 0;
  }
  eventsFile.writeAsStringSync(ContentFormatter.format(
      <String, dynamic>{'schemaVersion': 1, 'events': registry}));
  for (final e in newEras.entries) {
    File('${content.path}/eras/${e.key}.json')
        .writeAsStringSync(ContentFormatter.format(e.value));
  }
  stdout.writeln('✓ wrote content/events.json and $migrated era files');
  return 0;
}

/// Key-order-insensitive form of decoded JSON, so two values compare equal
/// when they hold the same data.
Object? _canonical(Object? v) => switch (v) {
      Map<String, dynamic>() => <String, Object?>{
          for (final k in (v.keys.toList()..sort())) k: _canonical(v[k]),
        },
      List() => [for (final x in v) _canonical(x)],
      _ => v,
    };
