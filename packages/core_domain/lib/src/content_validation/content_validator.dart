import 'dart:convert';

import 'package:json_schema/json_schema.dart';

/// One validation failure, tied to the file it came from — e.g. the CMS's
/// per-era validation badge groups these by [file].
class ContentIssue {
  const ContentIssue(this.file, this.message);

  final String file;
  final String message;

  @override
  String toString() => '$file: $message';
}

/// The result of [ContentValidator.validateAll] — both a structured
/// [issues] list (for a UI like the CMS's dashboard) and the exact
/// human-readable [lines] `tool/validate_content.dart` has always printed,
/// so extracting this out of the CLI script changed no CLI output.
class ContentValidationResult {
  const ContentValidationResult({
    required this.lines,
    required this.issues,
    required this.peopleCount,
    required this.periodCount,
    required this.eraCount,
  });

  final List<String> lines;
  final List<ContentIssue> issues;
  final int peopleCount;
  final int periodCount;
  final int eraCount;

  bool get isValid => issues.isEmpty;
}

/// Validates `content/`'s era/people/period JSON against their schemas, plus
/// the referential-integrity rules the schemas alone can't express (a
/// character ref must exist in the people registry, an event's figureIds
/// must be part of that era's own roster, an era's period must exist in the
/// period registry, and `index.json` must list exactly the eras on disk).
///
/// Pure — takes raw JSON text/maps in, never touches the filesystem — so
/// `tool/validate_content.dart` (reading from disk) and the CMS (reading a
/// draft from memory, before anything is saved) run the exact same checks.
abstract final class ContentValidator {
  /// [eraFiles] maps each era's filename (e.g. `"au-lac.json"`) to its raw
  /// JSON text. [indexJson] is optional — omit it to skip the
  /// listed-vs-on-disk cross-check (the CMS validates one era at a time and
  /// doesn't necessarily have the whole set loaded).
  static ContentValidationResult validateAll({
    required String eraSchemaJson,
    required String peopleSchemaJson,
    required String periodSchemaJson,
    required Map<String, String> eraFiles,
    required String peopleJson,
    required String periodsJson,
    String? indexJson,
  }) {
    final lines = <String>[];
    final issues = <ContentIssue>[];

    final eraSchema = JsonSchema.create(
      jsonDecode(eraSchemaJson) as Object,
      schemaVersion: SchemaVersion.draft2020_12,
    );
    final peopleSchema = JsonSchema.create(
      jsonDecode(peopleSchemaJson) as Object,
      schemaVersion: SchemaVersion.draft2020_12,
    );
    final periodSchema = JsonSchema.create(
      jsonDecode(periodSchemaJson) as Object,
      schemaVersion: SchemaVersion.draft2020_12,
    );

    // The people registry: validate it and collect the ids eras may reference.
    final peopleIds = <String>{};
    final peopleData = jsonDecode(peopleJson);
    final peopleResult = peopleSchema.validate(peopleData);
    if (!peopleResult.isValid) {
      lines.add('✗ people.json');
      for (final error in peopleResult.errors) {
        lines.add('    ${error.instancePath}: ${error.message}');
        issues.add(ContentIssue('people.json', error.message));
      }
    } else {
      for (final p in (peopleData as Map<String, dynamic>)['people'] as List) {
        peopleIds.add((p as Map<String, dynamic>)['id'] as String);
      }
      lines.add('✓ people.json (${peopleIds.length} people)');
    }

    // The period registry: validate it and collect the ids eras may reference.
    final periodIds = <String>{};
    final periodsData = jsonDecode(periodsJson);
    final periodsResult = periodSchema.validate(periodsData);
    if (!periodsResult.isValid) {
      lines.add('✗ periods.json');
      for (final error in periodsResult.errors) {
        lines.add('    ${error.instancePath}: ${error.message}');
        issues.add(ContentIssue('periods.json', error.message));
      }
    } else {
      for (final p in (periodsData as Map<String, dynamic>)['periods'] as List) {
        periodIds.add((p as Map<String, dynamic>)['id'] as String);
      }
      lines.add('✓ periods.json (${periodIds.length} periods)');
    }

    final slugsOnDisk = <String>{};
    final sortedNames = eraFiles.keys.toList()..sort();
    for (final name in sortedNames) {
      final data = jsonDecode(eraFiles[name]!);
      final result = eraSchema.validate(data);

      if (!result.isValid) {
        lines.add('✗ $name');
        for (final error in result.errors) {
          lines.add('    ${error.instancePath}: ${error.message}');
          issues.add(ContentIssue(name, error.message));
        }
        continue;
      }

      // Filename must match the declared slug.
      final eraMap = data as Map<String, dynamic>;
      final slug = eraMap['slug'];
      final expected = name.replaceAll('.json', '');
      if (slug != expected) {
        lines.add('✗ $name: slug "$slug" != filename "$expected"');
        issues.add(ContentIssue(name, 'slug "$slug" != filename "$expected"'));
        continue;
      }

      // Referential integrity: character refs must exist in the registry,
      // and event figureIds must be part of this era's roster.
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
        lines.add('✗ $name (references)');
        if (badRefs.isNotEmpty) {
          final msg = 'unknown person ref(s): ${badRefs.join(', ')}';
          lines.add('    $msg');
          issues.add(ContentIssue(name, msg));
        }
        if (badFigures.isNotEmpty) {
          final msg = 'figureId(s) not in roster: ${badFigures.join(', ')}';
          lines.add('    $msg');
          issues.add(ContentIssue(name, msg));
        }
        if (badPeriod) {
          final msg = 'unknown period: $period';
          lines.add('    $msg');
          issues.add(ContentIssue(name, msg));
        }
        continue;
      }

      slugsOnDisk.add(slug as String);
      lines.add('✓ $name');
    }

    // The bundled manifest must list exactly the era files present.
    if (indexJson != null) {
      final index = jsonDecode(indexJson);
      final listed = <String>{
        for (final s in (index as Map<String, dynamic>)['eras'] as List) s as String,
      };
      final missing = slugsOnDisk.difference(listed);
      final extra = listed.difference(slugsOnDisk);
      if (missing.isNotEmpty || extra.isNotEmpty) {
        lines.add('✗ content/index.json out of sync with content/eras/');
        if (missing.isNotEmpty) {
          final msg = 'not listed: ${missing.join(', ')}';
          lines.add('    $msg');
          issues.add(ContentIssue('index.json', msg));
        }
        if (extra.isNotEmpty) {
          final msg = 'listed but absent: ${extra.join(', ')}';
          lines.add('    $msg');
          issues.add(ContentIssue('index.json', msg));
        }
      } else {
        lines.add('✓ content/index.json');
      }
    }

    return ContentValidationResult(
      lines: lines,
      issues: issues,
      peopleCount: peopleIds.length,
      periodCount: periodIds.length,
      eraCount: slugsOnDisk.length,
    );
  }
}
