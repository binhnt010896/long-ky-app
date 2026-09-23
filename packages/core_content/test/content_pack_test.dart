import 'dart:convert';
import 'dart:io';

import 'package:core_content/core_content.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a real, valid pack JSON string from the repo's actual content, so
/// tests exercise the real parsers rather than a hand-rolled fixture that
/// might not match what `tool/build_content_pack.dart` actually produces.
String _validPackJson({int version = 20260923000000}) {
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
  final eras = <String, dynamic>{
    for (final s in slugs)
      s: jsonDecode(File('$root/eras/$s.json').readAsStringSync()),
  };
  return jsonEncode(<String, dynamic>{
    'schemaVersion': 1,
    'version': version,
    'index': index,
    'people': people,
    'periods': periods,
    'media': media,
    'eras': eras,
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
}
