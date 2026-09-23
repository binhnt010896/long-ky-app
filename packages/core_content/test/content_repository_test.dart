import 'dart:io';

import 'package:core_content/core_content.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

/// A [ContentSource] backed by the repo's real `content/` directory on disk.
/// The runtime uses [BundledContentSource] (AssetBundle); on disk we get the
/// same behaviour without registering Flutter assets in the test harness.
class DiskContentSource implements ContentSource {
  DiskContentSource(this.root);
  final Directory root;

  @override
  Future<List<String>> availableSlugs() async {
    final dir = Directory('${root.path}/eras');
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .map((f) => f.uri.pathSegments.last.replaceAll('.json', ''))
        .toList();
  }

  @override
  Future<String> loadEraJson(String slug) async {
    final file = File('${root.path}/eras/$slug.json');
    if (!file.existsSync()) {
      throw ContentSourceException('era not found on disk: $slug');
    }
    return file.readAsString();
  }

  @override
  Future<String> loadPeopleJson() async =>
      File('${root.path}/people.json').readAsString();

  @override
  Future<String> loadPeriodsJson() async =>
      File('${root.path}/periods.json').readAsString();
}

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
}

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
  });
}
