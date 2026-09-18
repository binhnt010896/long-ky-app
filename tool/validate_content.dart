// Validates every content/eras/*.json against content/era.schema.json, and
// cross-checks content/index.json. Run via `melos run validate:content` (CI).
//
// Usage: dart run tool/validate_content.dart
//
// Exits 0 when all files pass, 1 otherwise, printing the offending path(s).

import 'dart:convert';
import 'dart:io';

import 'package:json_schema/json_schema.dart';

Future<void> main() async {
  exitCode = await _run();
}

Future<int> _run() async {
  final root = Directory.current;
  final schemaFile = File('${root.path}/content/era.schema.json');
  final eraDir = Directory('${root.path}/content/eras');
  final indexFile = File('${root.path}/content/index.json');

  if (!schemaFile.existsSync()) {
    stderr.writeln('✗ schema not found: ${schemaFile.path}');
    return 1;
  }

  final schema = JsonSchema.create(
    jsonDecode(schemaFile.readAsStringSync()) as Object,
    schemaVersion: SchemaVersion.draft2020_12,
  );

  final eraFiles = eraDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (eraFiles.isEmpty) {
    stderr.writeln('✗ no era files found in ${eraDir.path}');
    return 1;
  }

  var ok = true;
  final slugsOnDisk = <String>{};

  // The people registry: validate it and collect the ids eras may reference.
  final peopleIds = <String>{};
  final peopleFile = File('${root.path}/content/people.json');
  final peopleSchemaFile = File('${root.path}/content/people.schema.json');
  if (!peopleFile.existsSync() || !peopleSchemaFile.existsSync()) {
    stderr.writeln('✗ people registry or schema not found');
    return 1;
  }
  final peopleSchema = JsonSchema.create(
    jsonDecode(peopleSchemaFile.readAsStringSync()) as Object,
    schemaVersion: SchemaVersion.draft2020_12,
  );
  final peopleData = jsonDecode(peopleFile.readAsStringSync());
  final peopleResult = peopleSchema.validate(peopleData);
  if (!peopleResult.isValid) {
    ok = false;
    stdout.writeln('✗ people.json');
    for (final error in peopleResult.errors) {
      stdout.writeln('    ${error.instancePath}: ${error.message}');
    }
  } else {
    for (final p in (peopleData as Map<String, dynamic>)['people'] as List) {
      peopleIds.add((p as Map<String, dynamic>)['id'] as String);
    }
    stdout.writeln('✓ people.json (${peopleIds.length} people)');
  }

  // The period registry: validate it and collect the ids eras may reference.
  final periodIds = <String>{};
  final periodsFile = File('${root.path}/content/periods.json');
  final periodsSchemaFile = File('${root.path}/content/period.schema.json');
  if (!periodsFile.existsSync() || !periodsSchemaFile.existsSync()) {
    stderr.writeln('✗ period registry or schema not found');
    return 1;
  }
  final periodsSchema = JsonSchema.create(
    jsonDecode(periodsSchemaFile.readAsStringSync()) as Object,
    schemaVersion: SchemaVersion.draft2020_12,
  );
  final periodsData = jsonDecode(periodsFile.readAsStringSync());
  final periodsResult = periodsSchema.validate(periodsData);
  if (!periodsResult.isValid) {
    ok = false;
    stdout.writeln('✗ periods.json');
    for (final error in periodsResult.errors) {
      stdout.writeln('    ${error.instancePath}: ${error.message}');
    }
  } else {
    for (final p in (periodsData as Map<String, dynamic>)['periods'] as List) {
      periodIds.add((p as Map<String, dynamic>)['id'] as String);
    }
    stdout.writeln('✓ periods.json (${periodIds.length} periods)');
  }

  for (final file in eraFiles) {
    final name = file.uri.pathSegments.last;
    final data = jsonDecode(file.readAsStringSync());
    final result = schema.validate(data);

    if (!result.isValid) {
      ok = false;
      stdout.writeln('✗ $name');
      for (final error in result.errors) {
        stdout.writeln('    ${error.instancePath}: ${error.message}');
      }
      continue;
    }

    // Filename must match the declared slug.
    final slug = (data as Map<String, dynamic>)['slug'];
    final expected = name.replaceAll('.json', '');
    if (slug != expected) {
      ok = false;
      stdout.writeln('✗ $name: slug "$slug" != filename "$expected"');
      continue;
    }
    // Referential integrity: character refs must exist in the registry, and
    // event figureIds must be part of this era's roster.
    final eraMap = data as Map<String, dynamic>;
    final refs = <String>{
      for (final c in (eraMap['characters'] as List? ?? const <dynamic>[]))
        (c as Map<String, dynamic>)['ref'] as String,
    };
    final badRefs = refs.difference(peopleIds);
    final badFigures = <String>{};
    for (final e in (eraMap['events'] as List? ?? const <dynamic>[])) {
      for (final fid in ((e as Map<String, dynamic>)['figureIds'] as List? ??
          const <dynamic>[])) {
        if (!refs.contains(fid)) badFigures.add(fid as String);
      }
    }
    // Referential integrity: the era's period must exist in the registry.
    final period = eraMap['period'];
    final badPeriod = period is String && !periodIds.contains(period);
    if (badRefs.isNotEmpty || badFigures.isNotEmpty || badPeriod) {
      ok = false;
      stdout.writeln('✗ $name (references)');
      if (badRefs.isNotEmpty) {
        stdout.writeln('    unknown person ref(s): ${badRefs.join(', ')}');
      }
      if (badFigures.isNotEmpty) {
        stdout.writeln('    figureId(s) not in roster: ${badFigures.join(', ')}');
      }
      if (badPeriod) {
        stdout.writeln('    unknown period: $period');
      }
      continue;
    }

    slugsOnDisk.add(slug as String);
    stdout.writeln('✓ $name');
  }

  // The bundled manifest must list exactly the era files present.
  if (indexFile.existsSync()) {
    final index = jsonDecode(indexFile.readAsStringSync());
    final listed = <String>{
      for (final s in (index as Map<String, dynamic>)['eras'] as List)
        s as String,
    };
    final missing = slugsOnDisk.difference(listed);
    final extra = listed.difference(slugsOnDisk);
    if (missing.isNotEmpty || extra.isNotEmpty) {
      ok = false;
      stdout.writeln('✗ content/index.json out of sync with content/eras/');
      if (missing.isNotEmpty) stdout.writeln('    not listed: ${missing.join(', ')}');
      if (extra.isNotEmpty) stdout.writeln('    listed but absent: ${extra.join(', ')}');
    } else {
      stdout.writeln('✓ content/index.json');
    }
  }

  stdout.writeln(ok
      ? '\nAll ${eraFiles.length} era file(s) valid.'
      : '\nContent validation FAILED.');
  return ok ? 0 : 1;
}
