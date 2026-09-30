// Validates every content/eras/*.json against content/era.schema.json, plus
// people.json/periods.json and referential integrity. Run via
// `melos run validate:content` (CI).
//
// The actual checks live in ContentValidator (packages/core_domain) so the
// CMS can run the exact same validation against an in-memory draft, before
// anything is saved — this script is just the disk I/O around it.
//
// Usage: dart run tool/validate_content.dart
//
// Exits 0 when all files pass, 1 otherwise, printing the offending path(s).

import 'dart:convert';
import 'dart:io';

import 'package:core_domain/core_domain.dart';

Future<void> main() async {
  exitCode = await _run();
}

Future<int> _run() async {
  final root = Directory.current;
  final schemaFile = File('${root.path}/content/era.schema.json');
  final eraDir = Directory('${root.path}/content/eras');
  final indexFile = File('${root.path}/content/index.json');
  final peopleFile = File('${root.path}/content/people.json');
  final peopleSchemaFile = File('${root.path}/content/people.schema.json');
  final periodsFile = File('${root.path}/content/periods.json');
  final periodsSchemaFile = File('${root.path}/content/period.schema.json');
  final eventsFile = File('${root.path}/content/events.json');
  final eventsSchemaFile = File('${root.path}/content/event.schema.json');

  if (!schemaFile.existsSync()) {
    stderr.writeln('✗ schema not found: ${schemaFile.path}');
    return 1;
  }
  if (!peopleFile.existsSync() || !peopleSchemaFile.existsSync()) {
    stderr.writeln('✗ people registry or schema not found');
    return 1;
  }
  if (!periodsFile.existsSync() || !periodsSchemaFile.existsSync()) {
    stderr.writeln('✗ period registry or schema not found');
    return 1;
  }

  final eraFiles = eraDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList();
  if (eraFiles.isEmpty) {
    stderr.writeln('✗ no era files found in ${eraDir.path}');
    return 1;
  }

  final result = ContentValidator.validateAll(
    eraSchemaJson: schemaFile.readAsStringSync(),
    peopleSchemaJson: peopleSchemaFile.readAsStringSync(),
    periodSchemaJson: periodsSchemaFile.readAsStringSync(),
    eraFiles: <String, String>{
      for (final f in eraFiles)
        f.uri.pathSegments.last: f.readAsStringSync(),
    },
    peopleJson: peopleFile.readAsStringSync(),
    periodsJson: periodsFile.readAsStringSync(),
    indexJson: indexFile.existsSync() ? indexFile.readAsStringSync() : null,
    eventSchemaJson:
        eventsFile.existsSync() ? eventsSchemaFile.readAsStringSync() : null,
    eventsJson: eventsFile.existsSync() ? eventsFile.readAsStringSync() : null,
  );

  for (final line in result.lines) {
    stdout.writeln(line);
  }

  // Cycle M: street maps (content/streets/<city>.json). Skipped silently when
  // the folder is absent. Geometry is cross-checked only if the generated
  // GeoJSON is on disk locally (CI runners don't hold long-ky-sources).
  var streetsOk = true;
  final streetsDir = Directory('${root.path}/content/streets');
  if (streetsDir.existsSync() && result.isValid) {
    // Street targets name an era's events, so hand the street rules eras with
    // their `{ref}` events inlined (the registry is already validated above).
    final eventsById = eventsFile.existsSync()
        ? eventJsonById(
            jsonDecode(eventsFile.readAsStringSync()) as Map<String, dynamic>)
        : const <String, Map<String, dynamic>>{};
    final eras = <Map<String, dynamic>>[
      for (final f in eraFiles)
        inlineEraEvents(
            jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
            eventsById),
    ];
    final peopleIds = <String>{
      for (final p in (jsonDecode(peopleFile.readAsStringSync())
          as Map<String, dynamic>)['people'] as List)
        (p as Map<String, dynamic>)['id'] as String,
    };
    for (final f in streetsDir.listSync().whereType<File>()) {
      final n = f.uri.pathSegments.last;
      if (!n.endsWith('.json') || n.startsWith('aliases')) continue;
      final map = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      Set<String>? geoIds;
      final geomRel = map['geometry'];
      if (geomRel is String) {
        final g = File('${root.path}/content/$geomRel');
        if (g.existsSync()) {
          geoIds = <String>{
            for (final feat in (jsonDecode(g.readAsStringSync())
                as Map<String, dynamic>)['features'] as List)
              ((feat as Map<String, dynamic>)['properties'] as Map<String, dynamic>)['id']
                  as String,
          };
        }
      }
      final problems = StreetMapValidator.validate(
        streetsJson: f.readAsStringSync(),
        peopleIds: peopleIds,
        eras: eras,
        geometryStreetIds: geoIds,
      );
      if (problems.isEmpty) {
        stdout.writeln('✓ streets/$n${geoIds == null ? ' (geometry not checked)' : ''}');
      } else {
        streetsOk = false;
        stdout.writeln('✗ streets/$n');
        for (final p in problems) {
          stdout.writeln('    $p');
        }
      }
    }
  }

  final ok = result.isValid && streetsOk;
  stdout.writeln(ok
      ? '\nAll ${eraFiles.length} era file(s) valid.'
      : '\nContent validation FAILED.');
  return ok ? 0 : 1;
}
