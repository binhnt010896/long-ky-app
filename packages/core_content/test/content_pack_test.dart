import 'dart:convert';
import 'dart:io';

import 'package:core_content/core_content.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a real, valid pack JSON string from the repo's actual content, so
/// tests exercise the real parsers rather than a hand-rolled fixture that
/// might not match what `tool/build_content_pack.dart` actually produces.
String _validPackJson({int version = 20260923000000, bool withStandalone = true}) {
  const root = '../../content';
  final index =
      jsonDecode(File('$root/index.json').readAsStringSync()) as Map<String, dynamic>;
  final people =
      jsonDecode(File('$root/people.json').readAsStringSync()) as Map<String, dynamic>;
  final periods =
      jsonDecode(File('$root/periods.json').readAsStringSync()) as Map<String, dynamic>;
  final media = jsonDecode(File('$root/media-manifest.json').readAsStringSync())
      as Map<String, dynamic>;
  final slugs = <String>[for (final s in index['eras'] as List) s as String];
  final events = jsonDecode(File('$root/events.json').readAsStringSync())
      as Map<String, dynamic>;
  final byId = eventJsonById(events);
  // As tool/build_content_pack.dart builds it: events inlined with `order`
  // (the shape every installed build parses), standalone ones on the side.
  final eraJsons = <String, Map<String, dynamic>>{
    for (final s in slugs)
      s: jsonDecode(File('$root/eras/$s.json').readAsStringSync())
          as Map<String, dynamic>,
  };
  final eras = <String, dynamic>{
    for (final e in eraJsons.entries) e.key: inlineEraEvents(e.value, byId),
  };
  final standaloneIds = standaloneEventIds(eraJsons.values, byId.keys);
  return jsonEncode(<String, dynamic>{
    'schemaVersion': 1,
    'version': version,
    'index': index,
    'people': people,
    'periods': periods,
    'media': media,
    'eras': eras,
    if (withStandalone)
      'standaloneEvents': <String, dynamic>{
        'schemaVersion': 1,
        'events': [for (final id in standaloneIds) byId[id]],
      },
  });
}

void main() {
  test('parseAndValidate accepts a real, valid pack', () {
    final pack = ContentPack.parseAndValidate(_validPackJson());
    expect(pack.version, 20260923000000);
    expect(pack.eras, isNotEmpty);
    expect(pack.eras.keys, contains('hong-bang-van-lang'));
  });

  test('parseAndValidate rejects malformed JSON', () {
    expect(() => ContentPack.parseAndValidate('not json'),
        throwsA(isA<ContentSourceException>()));
  });

  test('parseAndValidate rejects a schemaVersion newer than this app supports',
      () {
    final raw = jsonDecode(_validPackJson()) as Map<String, dynamic>;
    raw['schemaVersion'] = kSupportedPackSchema + 1;
    expect(() => ContentPack.parseAndValidate(jsonEncode(raw)),
        throwsA(isA<ContentSourceException>()));
  });

  test('parseAndValidate rejects a pack missing an era the index lists', () {
    final raw = jsonDecode(_validPackJson()) as Map<String, dynamic>;
    final eras = raw['eras'] as Map<String, dynamic>;
    final slug = (raw['index'] as Map<String, dynamic>)['eras'][0] as String;
    eras.remove(slug);
    expect(() => ContentPack.parseAndValidate(jsonEncode(raw)),
        throwsA(isA<ContentSourceException>()));
  });

  test('parseAndValidate rejects an era that fails to parse', () {
    final raw = jsonDecode(_validPackJson()) as Map<String, dynamic>;
    final eras = raw['eras'] as Map<String, dynamic>;
    final slug = (raw['index'] as Map<String, dynamic>)['eras'][0] as String;
    (eras[slug] as Map<String, dynamic>).remove('title');
    expect(() => ContentPack.parseAndValidate(jsonEncode(raw)),
        throwsA(isA<ContentSourceException>()));
  });

  test('parseAndValidate rejects an invalid people registry', () {
    final raw = jsonDecode(_validPackJson()) as Map<String, dynamic>;
    raw['people'] = <String, dynamic>{'not': 'a registry'};
    expect(() => ContentPack.parseAndValidate(jsonEncode(raw)),
        throwsA(isA<ContentSourceException>()));
  });

  group('PackContentSource', () {
    test('round-trips eras, people and periods through a ContentRepository',
        () async {
      final pack = ContentPack.parseAndValidate(_validPackJson());
      final repo = ContentRepository(PackContentSource(pack));
      final slugs = await repo.loadAllEras();
      expect(slugs, isNotEmpty);
      expect(slugs.map((e) => e.slug), contains('hong-bang-van-lang'));
      final periods = await repo.loadPeriods();
      expect(periods.ordered, isNotEmpty);
    });

    test('loadEraJson throws for an unknown slug', () async {
      final pack = ContentPack.parseAndValidate(_validPackJson());
      final source = PackContentSource(pack);
      expect(() => source.loadEraJson('not-a-real-slug'),
          throwsA(isA<ContentSourceException>()));
    });
  });

  group('standalone events (Cycle N)', () {
    test('a pack\'s eras parse with the registry-less parser an installed '
        'build uses — events inlined, with order', () {
      final raw = jsonDecode(_validPackJson()) as Map<String, dynamic>;
      final people = PeopleRegistry.fromJson(raw['people'] as Map<String, dynamic>);
      for (final entry in (raw['eras'] as Map<String, dynamic>).entries) {
        final era = Era.fromJson(entry.value as Map<String, dynamic>, people);
        expect(era.events, isNotEmpty, reason: entry.key);
      }
    });

    test('an old build simply ignores the extra standaloneEvents key', () {
      // parseAndValidate only reads the keys it knows; the extra one must not
      // fail a pack (this is why no schemaVersion bump was needed).
      final raw = jsonDecode(_validPackJson()) as Map<String, dynamic>;
      raw['someFutureKey'] = <String, dynamic>{'x': 1};
      expect(ContentPack.parseAndValidate(jsonEncode(raw)).eras, isNotEmpty);
    });

    test('the pack carries the standalone events and serves them', () async {
      final raw = jsonDecode(_validPackJson()) as Map<String, dynamic>;
      final standalone = raw['standaloneEvents'] as Map<String, dynamic>;
      (standalone['events'] as List).add(<String, dynamic>{
        'id': 'su-kien-rieng',
        'kind': 'historical',
        'year': {'value': 1945, 'display': {'vi': '1945'}},
        'title': {'vi': 'Sự kiện riêng'},
        'summary': {'vi': 'Tóm tắt'},
        'citation': {'work': 'Đại Việt sử ký toàn thư'},
      });
      final pack = ContentPack.parseAndValidate(jsonEncode(raw));
      final repo = ContentRepository(PackContentSource(pack));
      final events = await repo.loadStandaloneEvents();
      expect(events.map((e) => e.id), ['su-kien-rieng']);
      final found = await repo.findEvent('su-kien-rieng');
      expect(found?.isStandalone, isTrue);
    });

    test('a pack that predates standalone events defers instead of answering none',
        () async {
      final pack = ContentPack.parseAndValidate(_validPackJson(withStandalone: false));
      expect(pack.standaloneEvents, isNull);
      await expectLater(PackContentSource(pack).loadStandaloneEventsJson(),
          throwsA(isA<ContentSourceException>()));
    });

    test('an invalid standaloneEvents block rejects the whole pack', () {
      final raw = jsonDecode(_validPackJson()) as Map<String, dynamic>;
      raw['standaloneEvents'] = <String, dynamic>{
        'schemaVersion': 1,
        'events': [<String, dynamic>{'id': 'thieu-het'}],
      };
      expect(() => ContentPack.parseAndValidate(jsonEncode(raw)),
          throwsA(isA<ContentSourceException>()));
    });

    test('findEvent locates an in-era event with its era', () async {
      final repo = ContentRepository(PackContentSource(
          ContentPack.parseAndValidate(_validPackJson())));
      final found = await repo.findEvent('trieu-vu-de-lap-nam-viet');
      expect(found?.era?.slug, 'nha-trieu');
      expect(await repo.findEvent('khong-co-su-kien-nay'), isNull);
    });
  });
}
