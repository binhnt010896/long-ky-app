import 'dart:io';

import 'package:core_domain/core_domain.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_su/screens/streets/street_data.dart';
import 'package:viet_su/state/narration_controller.dart';
import 'package:viet_su/state/visit_store.dart';

import 'memory_stores.dart';

const _lyTuTrong = MappedStreet(
  id: 'ly-tu-trong',
  name: 'Lý Tự Trọng',
  status: StreetStatus.approved,
  targets: [StreetTarget(type: StreetTargetType.person, id: 'ly-tu-trong', era: '')],
);
const _haiBa = MappedStreet(
  id: 'hai-ba-trung',
  name: 'Hai Bà Trưng',
  status: StreetStatus.approved,
  targets: [
    StreetTarget(type: StreetTargetType.person, id: 'trung-trac', era: 'a'),
    StreetTarget(type: StreetTargetType.person, id: 'trung-nhi', era: 'a'),
  ],
);

class _Source implements StreetDataSource {
  const _Source();
  @override
  Future<StreetMapFile?> loadMapping() async => const StreetMapFile(
        city: 'hcm',
        osmSnapshot: 't',
        geometry: 'g',
        streets: [_lyTuTrong, _haiBa],
      );
  @override
  Future<StreetMapData?> loadAll() async => null;
}

ProviderContainer _container({
  VisitData data = const VisitData(),
  Set<String> heard = const <String>{},
  MemoryVisitStore? store,
}) {
  final c = ProviderContainer(overrides: [
    visitStoreProvider.overrideWithValue(store ?? MemoryVisitStore(data)),
    narrationStoreProvider.overrideWithValue(MemoryNarrationStore(heard)),
    streetDataSourceProvider.overrideWithValue(const _Source()),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('visitKeyForUri', () {
    String? k(String path) => visitKeyForUri(Uri.parse(path));

    test('pages of a person, an event or an era record a visit', () {
      expect(k('/era/au-lac'), 'era:au-lac');
      expect(k('/era/au-lac/timeline'), 'era:au-lac');
      expect(k('/era/au-lac/event/thuc-phan-xung-vuong'), 'event:thuc-phan-xung-vuong');
      expect(k('/era/au-lac/figure/an-duong-vuong'), 'person:an-duong-vuong');
      expect(k('/nhan-vat/ly-tu-trong'), 'person:ly-tu-trong');
      expect(k('/su-kien/dao-kenh-vinh-te'), 'event:dao-kenh-vinh-te');
    });

    test('every other page records nothing', () {
      for (final p in ['/', '/sanh', '/timeline', '/duong-pho?street=le-loi',
          '/sanh/cau-do/choi?mode=daily&seed=1', '/chao-co', '/map', '/hom-nay', '/era']) {
        expect(k(p), isNull, reason: p);
      }
    });
  });

  group('visitKeyFromNarrationKey', () {
    test('maps narration keys to visit keys', () {
      expect(visitKeyFromNarrationKey('eras/au-lac'), 'era:au-lac');
      expect(visitKeyFromNarrationKey('people/le-loi'), 'person:le-loi');
      expect(visitKeyFromNarrationKey('events/bach-dang'), 'event:bach-dang');
    });

    test('ignores keys it does not know', () {
      expect(visitKeyFromNarrationKey('other/x'), isNull);
      expect(visitKeyFromNarrationKey('people/'), isNull);
      expect(visitKeyFromNarrationKey('people'), isNull);
    });
  });

  group('FileVisitStore', () {
    test('round-trips across instances and survives a corrupt file', () async {
      final dir = Directory.systemTemp.createTempSync('visit_store_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async =>
              call.method == 'getApplicationSupportDirectory' ? dir.path : null);
      addTearDown(() => TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));

      await FileVisitStore().save(const VisitData(
          visited: {'person:a', 'event:b'}, backfilled: true));
      final back = await FileVisitStore().load();
      expect(back.visited, {'person:a', 'event:b'});
      expect(back.backfilled, isTrue);

      File('${dir.path}/visits.json').writeAsStringSync('not json');
      final bad = await FileVisitStore().load();
      expect(bad.visited, isEmpty);
      expect(bad.backfilled, isFalse);
    });
  });

  group('VisitedNotifier', () {
    test('first run imports the narration history, once', () async {
      final store = MemoryVisitStore(const VisitData()); // a first run
      final c = _container(
          store: store, heard: {'people/ly-tu-trong', 'eras/au-lac', 'weird'});
      expect(await c.read(visitedProvider.future), {'person:ly-tu-trong', 'era:au-lac'});
      expect(store.data.backfilled, isTrue);

      // A later start never re-imports (a reader's visits are only ever added).
      final again = _container(
          store: store, heard: {'people/someone-else'});
      expect(await again.read(visitedProvider.future), {'person:ly-tu-trong', 'era:au-lac'});
    });

    test('record adds a visit, persists it, and does nothing the second time', () async {
      final store = MemoryVisitStore(const VisitData(backfilled: true));
      final c = _container(store: store);
      await c.read(visitedProvider.future);
      await c.read(visitedProvider.notifier).record('person:x');
      expect(c.read(visitedProvider).value, {'person:x'});
      expect(store.data.visited, {'person:x'});
      final saves = store.saves;
      await c.read(visitedProvider.notifier).record('person:x');
      expect(store.saves, saves);
    });

    test('a visit that lights a street says so once; one that does not stays quiet', () async {
      final c = _container(data: const VisitData(backfilled: true));
      await c.read(visitedProvider.future);
      final notifier = c.read(visitedProvider.notifier);

      await notifier.record('person:nobody-has-a-street');
      expect(c.read(newlyLitProvider), isNull);

      await notifier.record(VisitKey.person('ly-tu-trong'));
      final lit = c.read(newlyLitProvider)!;
      expect(lit.key, 'person:ly-tu-trong');
      expect(lit.streets.map((s) => s.id), ['ly-tu-trong']);
      expect(c.read(discoveredStreetsProvider), {'ly-tu-trong'});
    });

    test('a second target of an already-lit street lights nothing new', () async {
      final c = _container(data: const VisitData(backfilled: true));
      await c.read(visitedProvider.future);
      final notifier = c.read(visitedProvider.notifier);
      await notifier.record(VisitKey.person('trung-trac'));
      expect(c.read(newlyLitProvider)!.streets.single.id, 'hai-ba-trung');
      c.read(newlyLitProvider.notifier).state = null;
      await notifier.record(VisitKey.person('trung-nhi'));
      expect(c.read(newlyLitProvider), isNull);
      expect(c.read(discoveredStreetsProvider), {'hai-ba-trung'});
    });
  });
}
