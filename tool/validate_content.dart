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
  );

  for (final line in result.lines) {
    stdout.writeln(line);
  }
  stdout.writeln(result.isValid
      ? '\nAll ${eraFiles.length} era file(s) valid.'
      : '\nContent validation FAILED.');
  return result.isValid ? 0 : 1;
}
