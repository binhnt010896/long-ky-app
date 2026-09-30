import 'dart:convert';
import 'dart:io';

import 'package:core_content/core_content.dart';
import 'package:core_content/testing.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A trivial in-memory source, for the OTA overlay test.
class MemoryContentSource implements ContentSource {
  MemoryContentSource(this.docs);
  final Map<String, String> docs;

  @override
  Future<List<String>> availableSlugs() async => docs.keys.toList();

  @override
  Future<String> loadEraJson(String slug) async {
    final doc = docs[slug];
    if (doc == null) throw ContentSourceException('not in memory: $slug');
    return doc;
  }

  // The people registry isn't kept in memory here; read the real one so eras
  // resolve their character refs.
  @override
  Future<String> loadPeopleJson() async =>
      File('../../content/people.json').readAsString();

  @override
  Future<String> loadPeriodsJson() async =>
      File('../../content/periods.json').readAsString();

  @override
  Future<String> loadStandaloneEventsJson() async =>
      '{"schemaVersion":1,"events":[]}';
}

/// An in-memory asset bundle, so [BundledContentSource] is exercised for real.
class _MapBundle extends AssetBundle {
  _MapBundle(this.files);
  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    final f = files[key];
    if (f == null) throw StateError('asset not found: $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(f)));
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final f = files[key];
    if (f == null) throw StateError('asset not found: $key');
    return f;
  }
}

Map<String, dynamic> _ev(String id) => <String, dynamic>{
      'id': id,
      'kind': 'historical',
      'year': {'value': 1000, 'display': {'vi': '1000'}},
      'title': {'vi': id},
      'summary': {'vi': id},
      'citation': {'work': 'x'},
    };

void main() {
  // cwd is the package root when `flutter test` runs.
  final contentRoot = Directory('../../content');

  group('ContentRepository over bundled-equivalent disk source', () {
    late ContentRepository repo;

    setUp(() => repo = ContentRepository(DiskContentSource(contentRoot)));

    test('loads the Hồng Bàng era end to end', () async {
      final era = await repo.loadEra('hong-bang-van-lang');
      expect(era.title.vi, 'Hồng Bàng & Văn Lang');
      expect(era.events, hasLength(7));
      expect(era.events[1].summary.vi, contains('trăm trứng'));
      expect(era.primarySource.work, 'Đại Việt sử ký toàn thư');
      // Character refs resolve against the people registry.
      expect(era.characters, hasLength(9));
      expect(era.figureById('lac-long-quan')!.epithet!.vi, 'Bố Rồng');
    });

    test('caches: the same instance is returned on re-read', () async {
      final a = await repo.loadEra('hong-bang-van-lang');
      final b = await repo.loadEra('hong-bang-van-lang');
      expect(identical(a, b), isTrue);
    });

    test('loadAllEras returns eras sorted by order', () async {
      final eras = await repo.loadAllEras();
      expect(eras, isNotEmpty);
      final orders = eras.map((e) => e.order).toList();
      final sorted = [...orders]..sort();
      expect(orders, sorted);
    });

    test('slug mismatch is rejected', () async {
      final repo = ContentRepository(
        MemoryContentSource({
          'wrong-slug': await DiskContentSource(contentRoot)
              .loadEraJson('hong-bang-van-lang'),
        }),
      );
      expect(
        () => repo.loadEra('wrong-slug'),
        throwsA(isA<ContentFormatException>()),
      );
    });
  });

  group('OtaContentSource seam', () {
    test('overlay content is preferred over bundled, with fallback', () async {
      final bundled = DiskContentSource(contentRoot);
      final ota = OtaContentSource(bundled: bundled);

      // Before any sync, reads come straight from the bundle.
      expect(await ota.loadEraJson('hong-bang-van-lang'), isNotEmpty);

      // Simulate a sync having staged a newer copy for one slug only.
      ota.overlay = MemoryContentSource({
        'hong-bang-van-lang':
            '{"schemaVersion":1,"id":"x","slug":"hong-bang-van-lang",'
                '"order":0,"title":{"vi":"OTA"},"kicker":{"vi":"k"},'
                '"subtitle":{"vi":"s"},"yearRange":{"display":{"vi":"y"}},'
                '"palette":{"accent":"#5f8f74"},'
                '"primarySource":{"work":"w"},'
                '"events":[{"id":"e","order":0,"kind":"legend",'
                '"year":{"display":{"vi":"Huyền sử"}},"title":{"vi":"t"},'
                '"summary":{"vi":"su"},"citation":{"work":"w"}}]}',
      });

      final repo = ContentRepository(ota);
      final overridden = await repo.loadEra('hong-bang-van-lang');
      expect(overridden.title.vi, 'OTA');

      // A slug the overlay lacks still falls back to the bundle union.
      expect(await ota.availableSlugs(), contains('hong-bang-van-lang'));
    });

    test('overlay is null until the app assigns one', () async {
      final ota = OtaContentSource(bundled: DiskContentSource(contentRoot));
      expect(ota.overlay, isNull);
    });

    // --- liveOverlay (Cycle K5 — Firestore, tried before the OTA pack) ----

    test('liveOverlay is preferred over overlay, which is preferred over bundled',
        () async {
      final bundled = DiskContentSource(contentRoot);
      final ota = OtaContentSource(bundled: bundled)
        ..overlay = MemoryContentSource({'au-lac': 'from-pack'})
        ..liveOverlay = MemoryContentSource({'au-lac': 'from-firestore'});

      expect(await ota.loadEraJson('au-lac'), 'from-firestore');
    });

    test('a slug only liveOverlay lacks falls through to overlay', () async {
      final bundled = DiskContentSource(contentRoot);
      final ota = OtaContentSource(bundled: bundled)
        ..overlay = MemoryContentSource({'au-lac': 'from-pack'})
        ..liveOverlay = MemoryContentSource(const {}); // e.g. not synced yet

      expect(await ota.loadEraJson('au-lac'), 'from-pack');
    });

    test('a liveOverlay that lacks everything falls all the way to bundled',
        () async {
      final bundled = DiskContentSource(contentRoot);
      final ota = OtaContentSource(bundled: bundled)
        ..liveOverlay = MemoryContentSource(const {});

      // No exception, no hang — just the bundled copy.
      expect(await ota.loadEraJson('au-lac'), isNotEmpty);
    });

    test('availableSlugs unions bundled, overlay and liveOverlay', () async {
      final bundled = DiskContentSource(contentRoot);
      final ota = OtaContentSource(bundled: bundled)
        ..overlay = MemoryContentSource({'from-pack-only': ''})
        ..liveOverlay = MemoryContentSource({'from-firestore-only': ''});

      final slugs = await ota.availableSlugs();
      expect(slugs, containsAll(['from-pack-only', 'from-firestore-only']));
      expect(slugs, contains('au-lac')); // still has the bundled set too
    });
  });

  group('BundledContentSource with an event registry', () {
    final bundle = _MapBundle({
      'index.json': jsonEncode({'schemaVersion': 1, 'eras': ['e1']}),
      'eras/e1.json': jsonEncode({
        'slug': 'e1',
        'events': [
          {'ref': 'b'},
          {'ref': 'a'},
        ],
      }),
      'events.json': jsonEncode({
        'schemaVersion': 1,
        'events': [_ev('a'), _ev('b'), _ev('alone')],
      }),
    });
    final source = BundledContentSource(
      bundle: bundle,
      manifestPath: 'index.json',
      eraDir: 'eras',
      eventsPath: 'events.json',
    );

    test('an era comes out with its events inlined, order = list position',
        () async {
      final era = jsonDecode(await source.loadEraJson('e1')) as Map<String, dynamic>;
      final events = (era['events'] as List).cast<Map<String, dynamic>>();
      expect(events.map((e) => e['id']), ['b', 'a']);
      expect(events.map((e) => e['order']), [0, 1]);
      expect(events.any((e) => e.containsKey('ref')), isFalse);
    });

    test('the events no era lists are the standalone ones', () async {
      final json = jsonDecode(await source.loadStandaloneEventsJson())
          as Map<String, dynamic>;
      expect((json['events'] as List).map((e) => (e as Map)['id']), ['alone']);
    });

    test('an already-inlined era needs no events asset, and has no standalone events',
        () async {
      final plain = BundledContentSource(
        bundle: _MapBundle({
          'index.json': jsonEncode({'schemaVersion': 1, 'eras': ['e1']}),
          'eras/e1.json': jsonEncode({
            'slug': 'e1',
            'events': [
              {..._ev('a'), 'order': 0},
            ],
          }),
        }),
        manifestPath: 'index.json',
        eraDir: 'eras',
        eventsPath: 'events.json',
      );
      expect(jsonDecode(await plain.loadEraJson('e1'))['events'], hasLength(1));
      final st = jsonDecode(await plain.loadStandaloneEventsJson()) as Map<String, dynamic>;
      expect(st['events'], isEmpty);
    });
  });

  group('OtaContentSource standalone events', () {
    final bundled = DiskContentSource(Directory('../../content'));

    test('an overlay with no word on them defers to the bundle', () async {
      final ota = OtaContentSource(
        bundled: bundled,
        overlay: _NoStandalone(bundled),
      );
      final json = jsonDecode(await ota.loadStandaloneEventsJson()) as Map<String, dynamic>;
      expect(json['schemaVersion'], 1);
    });
  });
}

/// A source that never answers for standalone events (a pre-Cycle-N pack).
class _NoStandalone implements ContentSource {
  _NoStandalone(this.inner);
  final ContentSource inner;
  @override
  Future<List<String>> availableSlugs() => inner.availableSlugs();
  @override
  Future<String> loadEraJson(String slug) => inner.loadEraJson(slug);
  @override
  Future<String> loadPeopleJson() => inner.loadPeopleJson();
  @override
  Future<String> loadPeriodsJson() => inner.loadPeriodsJson();
  @override
  Future<String> loadStandaloneEventsJson() async =>
      throw ContentSourceException('predates standalone events');
}
