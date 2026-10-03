import 'dart:convert';
import 'dart:io';

import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

/// The real files on disk, loaded the same way tool/format_content.dart and
/// tool/validate_content.dart do — no fixtures, so this test suite catches
/// the same problems those CLI tools would.
String _read(String relPath) => File('../../content/$relPath').readAsStringSync();

/// Era files exactly as authored now: events are `{ref}` items into events.json.
Map<String, String> _refEraTexts() => <String, String>{
      for (final f in _eraFiles()) f.uri.pathSegments.last: f.readAsStringSync(),
    };

/// The same eras with every event inlined (and `order` stamped) — the shape
/// an era had before the registry existed, which the validator still accepts.
Map<String, String> _inlineEraTexts() {
  final byId = eventJsonById(jsonDecode(_read('events.json')) as Map<String, dynamic>);
  return <String, String>{
    for (final e in _refEraTexts().entries)
      e.key: jsonEncode(
          inlineEraEvents(jsonDecode(e.value) as Map<String, dynamic>, byId)),
  };
}

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
        File('../../content/events.json'),
        File('../../content/event.schema.json'),
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
      final eraFiles = _refEraTexts();
      final result = ContentValidator.validateAll(
        eraSchemaJson: _read('era.schema.json'),
        peopleSchemaJson: _read('people.schema.json'),
        periodSchemaJson: _read('period.schema.json'),
        eraFiles: eraFiles,
        peopleJson: _read('people.json'),
        periodsJson: _read('periods.json'),
        indexJson: _read('index.json'),
        eventSchemaJson: _read('event.schema.json'),
        eventsJson: _read('events.json'),
      );
      expect(result.isValid, isTrue, reason: result.issues.join('\n'));
      expect(result.eraCount, eraFiles.length);
      expect(result.eventCount, 237);
      expect(result.standaloneEventCount, 0);
      expect(result.peopleCount, greaterThan(0));
      expect(result.periodCount, greaterThan(0));
    });

    test('flags a schema violation with a structured issue', () {
      final eraFiles = _inlineEraTexts();
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
      final eraFiles = _inlineEraTexts();
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
      final eraFiles = _inlineEraTexts();
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

    // --- Event integrity (Cycle K's events editor relies on these) --------

    Map<String, String> erasWithFirstEventEdited(
        Map<String, dynamic> Function(Map<String, dynamic> firstEvent) edit) {
      final eraFiles = _inlineEraTexts();
      final broken = Map<String, String>.of(eraFiles);
      final oneName = broken.keys.first;
      final data = jsonDecode(broken[oneName]!) as Map<String, dynamic>;
      final events = (data['events'] as List).cast<Map<String, dynamic>>();
      events[0] = edit(Map<String, dynamic>.of(events[0]));
      data['events'] = events;
      broken[oneName] = jsonEncode(data);
      return broken;
    }

    ContentValidationResult validateEras(Map<String, String> eraFiles) =>
        ContentValidator.validateAll(
          eraSchemaJson: _read('era.schema.json'),
          peopleSchemaJson: _read('people.schema.json'),
          periodSchemaJson: _read('period.schema.json'),
          eraFiles: eraFiles,
          peopleJson: _read('people.json'),
          periodsJson: _read('periods.json'),
        );

    test('flags an event whose slug disagrees with its id', () {
      final broken = erasWithFirstEventEdited((e) => e..['slug'] = 'wrong-slug');
      final result = validateEras(broken);
      expect(result.isValid, isFalse);
      expect(result.issues.any((i) => i.message.contains('!= id')), isTrue);
    });

    test('flags a duplicate event id across two different eras', () {
      final eraFiles = _inlineEraTexts();
      final names = eraFiles.keys.toList()..sort();
      final firstData = jsonDecode(eraFiles[names[0]]!) as Map<String, dynamic>;
      final firstEventId =
          ((firstData['events'] as List).first as Map<String, dynamic>)['id'];

      final broken = Map<String, String>.of(eraFiles);
      final secondData = jsonDecode(broken[names[1]]!) as Map<String, dynamic>;
      final secondEvents = (secondData['events'] as List).cast<Map<String, dynamic>>();
      secondEvents[0] = Map<String, dynamic>.of(secondEvents[0])
        ..['id'] = firstEventId
        ..remove('slug');
      secondData['events'] = secondEvents;
      broken[names[1]] = jsonEncode(secondData);

      final result = validateEras(broken);
      expect(result.isValid, isFalse);
      expect(
        result.issues.any((i) => i.message.contains('also used in ${names[0]}')),
        isTrue,
      );
    });

    test('flags a non-contiguous event order', () {
      final broken = erasWithFirstEventEdited((e) => e..['order'] = 99);
      final result = validateEras(broken);
      expect(result.isValid, isFalse);
      expect(result.issues.any((i) => i.message.contains('contiguous')), isTrue);
    });

    test('flags a relatedEventIds entry pointing at an unknown event', () {
      final broken =
          erasWithFirstEventEdited((e) => e..['relatedEventIds'] = <String>['no-such-event-xyz']);
      final result = validateEras(broken);
      expect(result.isValid, isFalse);
      expect(result.issues.any((i) => i.message.contains('unknown event')), isTrue);
    });

    test('flags an event that relates to itself', () {
      final broken = erasWithFirstEventEdited((e) => e..['relatedEventIds'] = <String>[e['id'] as String]);
      final result = validateEras(broken);
      expect(result.isValid, isFalse);
      expect(result.issues.any((i) => i.message.contains('references itself')), isTrue);
    });
  });

  // --- The event registry (Cycle N) ---------------------------------------

  group('ContentValidator — event registry', () {
    Map<String, dynamic> registry() =>
        jsonDecode(_read('events.json')) as Map<String, dynamic>;

    ContentValidationResult validate(
      Map<String, String> eraFiles,
      Map<String, dynamic> events,
    ) =>
        ContentValidator.validateAll(
          eraSchemaJson: _read('era.schema.json'),
          peopleSchemaJson: _read('people.schema.json'),
          periodSchemaJson: _read('period.schema.json'),
          eraFiles: eraFiles,
          peopleJson: _read('people.json'),
          periodsJson: _read('periods.json'),
          eventSchemaJson: _read('event.schema.json'),
          eventsJson: jsonEncode(events),
        );

    /// A valid standalone event: dated, with a hero, figures on a roster.
    Map<String, dynamic> standalone(Map<String, dynamic> template,
            {String id = 'su-kien-rieng'}) =>
        <String, dynamic>{
          ...template,
          'id': id,
          'slug': id,
          'relatedEventIds': <String>[],
        }..remove('order');

    Map<String, dynamic> firstEvent() =>
        Map<String, dynamic>.of((registry()['events'] as List).first as Map<String, dynamic>);

    test('an event no era lists is standalone, and a valid one passes', () {
      final events = registry();
      (events['events'] as List).add(standalone(firstEvent()));
      final result = validate(_refEraTexts(), events);
      expect(result.isValid, isTrue, reason: result.issues.join('\n'));
      expect(result.eventCount, 238);
      expect(result.standaloneEventCount, 1);
    });

    test('a standalone event needs a dated year', () {
      final events = registry();
      final e = standalone(firstEvent())..['year'] = <String, dynamic>{'display': <String, dynamic>{'vi': 'Không rõ'}};
      (events['events'] as List).add(e);
      final result = validate(_refEraTexts(), events);
      expect(result.isValid, isFalse);
      expect(result.issues.any((i) => i.message.contains('dated year')), isTrue);
    });

    test('a standalone event needs a hero', () {
      final events = registry();
      (events['events'] as List).add(standalone(firstEvent())..remove('hero'));
      final result = validate(_refEraTexts(), events);
      expect(result.isValid, isFalse);
      expect(result.issues.any((i) => i.message.contains('hero')), isTrue);
    });

    test('a standalone event\'s figures must be in the people registry', () {
      final events = registry();
      (events['events'] as List)
          .add(standalone(firstEvent())..['figureIds'] = <String>['khong-co-ai-ca-xyz']);
      final result = validate(_refEraTexts(), events);
      expect(result.isValid, isFalse);
      expect(result.issues.any((i) => i.message.contains('not in people.json')), isTrue);
    });

    test('an in-era event\'s figures must still be on that era\'s roster', () {
      final events = registry();
      (events['events'] as List).first['figureIds'] = <String>['khong-co-ai-ca-xyz'];
      final result = validate(_refEraTexts(), events);
      expect(result.isValid, isFalse);
      expect(result.issues.any((i) => i.message.contains('not in roster')), isTrue);
    });

    test('a ref to an event the registry does not have is flagged', () {
      final texts = _refEraTexts();
      final name = texts.keys.first;
      final data = jsonDecode(texts[name]!) as Map<String, dynamic>;
      (data['events'] as List).add(<String, String>{'ref': 'no-such-event-xyz'});
      texts[name] = jsonEncode(data);
      final result = validate(texts, registry());
      expect(result.isValid, isFalse);
      expect(result.issues.any((i) => i.file == name && i.message.contains('no-such-event-xyz')), isTrue);
    });

    test('an event listed by two eras is flagged (at most one era)', () {
      final texts = _refEraTexts();
      final names = texts.keys.toList()..sort();
      final a = jsonDecode(texts[names[0]]!) as Map<String, dynamic>;
      final b = jsonDecode(texts[names[1]]!) as Map<String, dynamic>;
      (b['events'] as List).add((a['events'] as List).first);
      texts[names[1]] = jsonEncode(b);
      final result = validate(texts, registry());
      expect(result.isValid, isFalse);
      expect(result.issues.any((i) => i.message.contains('also used in')), isTrue);
    });

    test('an event listed twice in one era is flagged', () {
      final texts = _refEraTexts();
      final name = texts.keys.first;
      final data = jsonDecode(texts[name]!) as Map<String, dynamic>;
      (data['events'] as List).add((data['events'] as List).first);
      texts[name] = jsonEncode(data);
      final result = validate(texts, registry());
      expect(result.isValid, isFalse);
      expect(result.issues.any((i) => i.message.contains('more than once')), isTrue);
    });

    test('a duplicate id inside events.json is flagged', () {
      final events = registry();
      (events['events'] as List).add(Map<String, dynamic>.of((events['events'] as List).first as Map<String, dynamic>));
      final result = validate(_refEraTexts(), events);
      expect(result.isValid, isFalse);
      expect(result.issues.any((i) => i.file == 'events.json' && i.message.contains('duplicate event id')), isTrue);
    });

    test('an era event may relate to a standalone event, and to another era\'s', () {
      final events = registry();
      (events['events'] as List).add(standalone(firstEvent()));
      (events['events'] as List).first['relatedEventIds'] = <String>['su-kien-rieng'];
      final list = events['events'] as List;
      list[1]['relatedEventIds'] = <String>[list.last['id'] as String];
      final result = validate(_refEraTexts(), events);
      expect(result.isValid, isTrue, reason: result.issues.join('\n'));
    });

    test('an event may not be both inlined in an era and defined in events.json', () {
      final texts = _inlineEraTexts();
      final name = (texts.keys.toList()..sort()).first;
      final data = jsonDecode(texts[name]!) as Map<String, dynamic>;
      final inlineFirst = (data['events'] as List).first as Map<String, dynamic>;
      // A registry holding just that event: its id is now defined twice —
      // inline in the era and in events.json.
      final events = <String, dynamic>{
        'schemaVersion': 1,
        'events': <dynamic>[Map<String, dynamic>.of(inlineFirst)..remove('order')],
      };
      final result = validate(texts, events);
      expect(result.isValid, isFalse);
      expect(result.issues.any((i) => i.message.contains('also defined in events.json')), isTrue);
    });
  });
}
