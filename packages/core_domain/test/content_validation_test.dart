import 'dart:convert';
import 'dart:io';

import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

/// The real files on disk, loaded the same way tool/format_content.dart and
/// tool/validate_content.dart do — no fixtures, so this test suite catches
/// the same problems those CLI tools would.
String _read(String relPath) => File('../../content/$relPath').readAsStringSync();

List<File> _eraFiles() => Directory('../../content/eras')
    .listSync()
    .whereType<File>()
    .where((f) => f.path.endsWith('.json'))
    .toList();

void main() {
  group('ContentFormatter', () {
    test('produces a deterministic, idempotent canonical form', () {
      const decoded = <String, dynamic>{
        'b': 1,
        'a': <String, dynamic>{'vi': 'x', 'en': 'y'},
      };
      final once = ContentFormatter.format(decoded);
      final twice = ContentFormatter.reformat(once);
      expect(once, twice);
      expect(ContentFormatter.isCanonical(once), isTrue);
    });

    test('reformatting never changes the decoded data', () {
      const source = '{"z":1,"a":[3,2,1],"m":{"vi":"c","en":"d"}}';
      final before = jsonDecode(source);
      final after = jsonDecode(ContentFormatter.reformat(source));
      expect(after, equals(before));
    });

    test('every real content JSON file on disk is already canonical', () {
      final files = <File>[
        File('../../content/index.json'),
        File('../../content/people.json'),
        File('../../content/periods.json'),
        File('../../content/content-version.json'),
        File('../../content/media-manifest.json'),
        File('../../content/era.schema.json'),
        File('../../content/people.schema.json'),
        File('../../content/period.schema.json'),
        ..._eraFiles(),
      ];
      for (final file in files) {
        final source = file.readAsStringSync();
        expect(
          ContentFormatter.isCanonical(source),
          isTrue,
          reason: '${file.path} is not canonically formatted — run '
              '`dart run tool/format_content.dart`',
        );
      }
    });

    test('throws FormatException on invalid JSON', () {
      expect(() => ContentFormatter.reformat('{not json'),
          throwsFormatException);
    });
  });

  group('ContentValidator', () {
    test('the real content set validates clean, with the expected counts', () {
      final eraFiles = <String, String>{
        for (final f in _eraFiles()) f.uri.pathSegments.last: f.readAsStringSync(),
      };
      final result = ContentValidator.validateAll(
        eraSchemaJson: _read('era.schema.json'),
        peopleSchemaJson: _read('people.schema.json'),
        periodSchemaJson: _read('period.schema.json'),
        eraFiles: eraFiles,
        peopleJson: _read('people.json'),
        periodsJson: _read('periods.json'),
        indexJson: _read('index.json'),
      );
      expect(result.isValid, isTrue, reason: result.issues.join('\n'));
      expect(result.eraCount, eraFiles.length);
      expect(result.peopleCount, greaterThan(0));
      expect(result.periodCount, greaterThan(0));
    });

    test('flags a schema violation with a structured issue', () {
      final eraFiles = <String, String>{
        for (final f in _eraFiles()) f.uri.pathSegments.last: f.readAsStringSync(),
      };
      // Drop a required field from one era to force a schema failure.
      final broken = Map<String, String>.of(eraFiles);
      final oneName = broken.keys.first;
      final data = jsonDecode(broken[oneName]!) as Map<String, dynamic>
        ..remove('title');
      broken[oneName] = jsonEncode(data);

      final result = ContentValidator.validateAll(
        eraSchemaJson: _read('era.schema.json'),
        peopleSchemaJson: _read('people.schema.json'),
        periodSchemaJson: _read('period.schema.json'),
        eraFiles: broken,
        peopleJson: _read('people.json'),
        periodsJson: _read('periods.json'),
      );
      expect(result.isValid, isFalse);
      expect(result.issues.any((i) => i.file == oneName), isTrue);
    });

    test('flags an unknown person ref', () {
      final eraFiles = <String, String>{
        for (final f in _eraFiles()) f.uri.pathSegments.last: f.readAsStringSync(),
      };
      final broken = Map<String, String>.of(eraFiles);
      final oneName = broken.keys.first;
      final data = jsonDecode(broken[oneName]!) as Map<String, dynamic>;
      data['characters'] = <dynamic>[
        ...(data['characters'] as List? ?? const <dynamic>[]),
        <String, String>{'ref': 'no-such-person-xyz'},
      ];
      broken[oneName] = jsonEncode(data);

      final result = ContentValidator.validateAll(
        eraSchemaJson: _read('era.schema.json'),
        peopleSchemaJson: _read('people.schema.json'),
        periodSchemaJson: _read('period.schema.json'),
        eraFiles: broken,
        peopleJson: _read('people.json'),
        periodsJson: _read('periods.json'),
      );
      expect(result.isValid, isFalse);
      expect(
        result.issues.any((i) =>
            i.file == oneName && i.message.contains('no-such-person-xyz')),
        isTrue,
      );
    });

    test('index.json cross-check is skipped when indexJson is omitted', () {
      final eraFiles = <String, String>{
        for (final f in _eraFiles()) f.uri.pathSegments.last: f.readAsStringSync(),
      };
      final result = ContentValidator.validateAll(
        eraSchemaJson: _read('era.schema.json'),
        peopleSchemaJson: _read('people.schema.json'),
        periodSchemaJson: _read('period.schema.json'),
        eraFiles: eraFiles,
        peopleJson: _read('people.json'),
        periodsJson: _read('periods.json'),
      );
      expect(result.isValid, isTrue);
      expect(result.lines.any((l) => l.contains('index.json')), isFalse);
    });
  });
}
