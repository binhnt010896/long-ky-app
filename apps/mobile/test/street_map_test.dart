import 'dart:io';

import 'package:core_content/core_content.dart';
import 'package:core_content/testing.dart';
import 'package:core_domain/core_domain.dart';
import 'package:experience/experience.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:viet_su/app_router.dart';
import 'package:viet_su/screens/character/character_detail_screen.dart';
import 'package:viet_su/screens/streets/street_basemap.dart';
import 'package:viet_su/screens/streets/street_card.dart';
import 'package:viet_su/screens/streets/street_data.dart';
import 'package:viet_su/screens/streets/street_map_screen.dart';
import 'package:viet_su/screens/streets/street_reverse_chip.dart';
import 'package:viet_su/state/providers.dart';
import 'package:viet_su/telemetry/route_telemetry.dart';
import 'package:viet_su/telemetry/telemetry.dart';


class _Events implements Telemetry {
  final List<(String, Map<String, Object>)> events = [];
  @override
  Future<void> event(String name, [Map<String, Object> params = const {}]) async =>
      events.add((name, params));
  @override
  Future<void> screen(String name, [Map<String, Object> params = const {}]) async {}
  @override
  Future<void> recordError(Object error, StackTrace stackTrace,
      {String? reason, bool fatal = false}) async {}
  @override
  Future<void> setEnabled(bool enabled) async {}
}

const _le = MappedStreet(
  id: 'le-loi',
  name: 'Lê Lợi',
  status: StreetStatus.approved,
  targets: [StreetTarget(type: StreetTargetType.person, id: 'le-loi', era: 'le-loi')],
);
const _bach = MappedStreet(
  id: 'bach-dang',
  name: 'Bạch Đằng',
  status: StreetStatus.approved,
  targets: [
    StreetTarget(type: StreetTargetType.event, id: 'chien-thang-bach-dang', era: 'ngo-quyen'),
    StreetTarget(type: StreetTargetType.event, id: 'bach-dang-1288', era: 'tran-hung-dao'),
    StreetTarget(type: StreetTargetType.era, id: 'hong-bang-van-lang', era: 'hong-bang-van-lang'),
  ],
);
const _hidden = MappedStreet(
  id: 'unapproved',
  name: 'Chưa duyệt',
  status: StreetStatus.suggested,
  targets: [StreetTarget(type: StreetTargetType.era, id: 'au-lac', era: 'au-lac')],
);

const _mapping = StreetMapFile(
    city: 'hcm',
    osmSnapshot: 't',
    geometry: 'streets/hcm-streets.geojson',
    streets: [_le, _bach, _hidden]);

// A small fake city: boundary 10.70–10.90 N, 106.60–106.80 E. Lê Lợi runs
// west–east through the middle; Bạch Đằng runs north–south east of it.
const _boundary = '''
{"type":"Feature","properties":{},"geometry":{"type":"Polygon","coordinates":
[[[106.60,10.70],[106.80,10.70],[106.80,10.90],[106.60,10.90],[106.60,10.70]]]}}''';
const _streets = '''
{"type":"FeatureCollection","features":[
 {"type":"Feature","properties":{"id":"le-loi"},"geometry":{"type":"MultiLineString","coordinates":[[[106.60,10.80],[106.80,10.80]]]}},
 {"type":"Feature","properties":{"id":"bach-dang"},"geometry":{"type":"MultiLineString","coordinates":[[[106.75,10.70],[106.75,10.90]]]}},
 {"type":"Feature","properties":{"id":"unapproved"},"geometry":{"type":"MultiLineString","coordinates":[[[106.62,10.72],[106.78,10.72]]]}}
]}''';

class _FakeSource implements StreetDataSource {
  const _FakeSource({this.withData = true});
  final bool withData;
  StreetMapFile? get mapping => _mapping;

  @override
  Future<StreetMapFile?> loadMapping() async => mapping;

  @override
  Future<StreetMapData?> loadAll() async => withData && mapping != null
      ? parseStreetMapData(
          file: mapping!, boundaryGeoJson: _boundary, streetsGeoJson: _streets)
      : null;
}

Future<(GoRouter, _Events)> _pump(
  WidgetTester tester,
  String location, {
  StreetDataSource source = const _FakeSource(),
}) async {
  final telemetry = _Events();
  final container = ProviderContainer(overrides: [
    contentRepositoryProvider.overrideWithValue(ContentRepository(DiskContentSource(Directory('../../content')))),
    streetDataSourceProvider.overrideWithValue(source),
    telemetryProvider.overrideWithValue(telemetry),
  ]);
  addTearDown(container.dispose);
  final router = container.read(routerProvider);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: ExperienceScope(
      tier: ExperienceTier.reduced,
      child: MaterialApp.router(routerConfig: router, theme: VSTheme.build()),
    ),
  ));
  router.go(location);
  // Resolve the data + era futures (each hop needs its own frame).
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return (router, telemetry);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1.0;
  });

  group('parseStreetMapData', () {
    test('keeps only approved streets and locks bounds to boundary + margin', () {
      final d = parseStreetMapData(
          file: _mapping, boundaryGeoJson: _boundary, streetsGeoJson: _streets);
      expect(d.lines.keys.toSet(), {'le-loi', 'bach-dang'});
      expect(d.bounds.south, closeTo(10.70 - kStreetBoundsMargin, 1e-9));
      expect(d.bounds.north, closeTo(10.90 + kStreetBoundsMargin, 1e-9));
      expect(d.bounds.west, closeTo(106.60 - kStreetBoundsMargin, 1e-9));
      expect(d.bounds.east, closeTo(106.80 + kStreetBoundsMargin, 1e-9));
    });

    test('an empty boundary is an error, never an unbounded map', () {
      expect(
          () => parseStreetMapData(
              file: _mapping,
              boundaryGeoJson: '{"type":"Polygon","coordinates":[]}',
              streetsGeoJson: _streets),
          throwsFormatException);
    });
  });

  group('basemap (sovereignty guard)', () {
    test('sea/ocean labels are removed from the theme', () {
      final ids = [for (final l in streetBasemapLayers()) l['id']];
      expect(ids, isNot(contains('water_label_ocean')));
      expect(ids, isNot(contains('boundaries_country')));
      expect(ids, contains('water'));
      expect(ids, contains('roads_highway'));
    });

    test('the filtered theme still parses', () {
      expect(buildStreetBasemapTheme(), isNotNull);
    });

    test('camera limits keep the view inside the boundary', () {
      expect(kStreetMinZoom, greaterThanOrEqualTo(10));
    });
  });

  test('routeForTarget: people and eras use their era routes; an event opens by id', () {
    expect(routeForTarget(_le.targets.single), '/era/le-loi/figure/le-loi');
    // An event opens by id alone — the router sends one that sits in an era on
    // to its era route, and a standalone event has no era.
    expect(routeForTarget(_bach.targets[0]), '/su-kien/chien-thang-bach-dang');
    expect(routeForTarget(_bach.targets[2]), '/era/hong-bang-van-lang');
  });

  test('telemetry maps /duong-pho', () {
    final v = mapUriToScreen(Uri.parse('/duong-pho?street=le-loi'))!;
    expect(v.name, 'street_map');
    expect(v.params, {'street_id': 'le-loi'});
    expect(mapUriToScreen(Uri.parse('/duong-pho'))!.params, isEmpty);
  });

  testWidgets('map: tap a gold street opens its card; tap elsewhere closes it',
      (tester) async {
    final (_, tel) = await _pump(tester, '/duong-pho');
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byKey(const Key('street-attribution')), findsOneWidget);
    expect(find.textContaining('OpenStreetMap contributors'), findsOneWidget);
    expect(find.text('Lê Lợi'), findsNothing);

    // Find where Lê Lợi actually is on screen, using the live camera.
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    final ctrl = map.mapController!;
    final s = ctrl.camera.latLngToScreenPoint(const LatLng(10.80, 106.70));
    final origin = tester.getTopLeft(find.byType(FlutterMap));
    await tester.tapAt(origin + Offset(s.x, s.y));
    await _settle(tester);

    expect(find.text('Lê Lợi'), findsWidgets);
    expect(find.byKey(const Key('street-open-person-le-loi')), findsOneWidget);
    expect(tel.events.map((e) => e.$1), contains('street_tap'));

    // Far from any street → dismissed (plain basemap is not tappable, M2).
    await tester.tapAt(origin + Offset(s.x, s.y - 150));
    await _settle(tester);
    expect(find.byKey(const Key('street-open-person-le-loi')), findsNothing);
  });

  testWidgets('map: ?street= opens with the card already up', (tester) async {
    await _pump(tester, '/duong-pho?street=bach-dang');
    expect(find.text('Bạch Đằng'), findsWidgets);
    // Three targets → three rows, each with its own button.
    expect(find.byKey(const Key('street-open-event-chien-thang-bach-dang')),
        findsOneWidget);
    expect(find.byKey(const Key('street-open-event-bach-dang-1288')), findsOneWidget);
    expect(find.byKey(const Key('street-open-era-hong-bang-van-lang')),
        findsOneWidget);
  });

  testWidgets('card button deep-links to the figure page and logs it',
      (tester) async {
    final (_, tel) = await _pump(tester, '/duong-pho?street=le-loi');
    await tester.tap(find.byKey(const Key('street-open-person-le-loi')));
    await tester.pump();
    await _settle(tester);
    // Pushed onto the stack: the real Character page is now on screen.
    expect(find.byType(CharacterDetailScreen), findsOneWidget);
    expect(
        tel.events.any((e) =>
            e.$1 == 'street_open_detail' &&
            e.$2['street_id'] == 'le-loi' &&
            e.$2['target'] == 'person:le-loi'),
        isTrue);
  });

  testWidgets('search flies to a street and shows its card', (tester) async {
    await _pump(tester, '/duong-pho');
    await tester.enterText(find.byKey(const Key('street-search')), 'bạch');
    await tester.pump();
    expect(find.byKey(const Key('street-result-bach-dang')), findsOneWidget);
    // Unapproved streets are not searchable.
    await tester.enterText(find.byKey(const Key('street-search')), 'chưa');
    await tester.pump();
    expect(find.byKey(const Key('street-result-unapproved')), findsNothing);

    await tester.enterText(find.byKey(const Key('street-search')), 'bạch');
    await tester.pump();
    await tester.tap(find.byKey(const Key('street-result-bach-dang')));
    await _settle(tester);
    expect(find.byKey(const Key('street-open-event-bach-dang-1288')), findsOneWidget);
  });

  testWidgets('no data → a calm message, never an unbounded map', (tester) async {
    await _pump(tester, '/duong-pho', source: const _FakeSource(withData: false));
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.textContaining('chưa sẵn sàng'), findsOneWidget);
  });

  testWidgets('reverse chip: shown for a target, hidden otherwise, opens the map',
      (tester) async {
    final container = ProviderContainer(overrides: [
      streetDataSourceProvider.overrideWithValue(const _FakeSource()),
    ]);
    addTearDown(container.dispose);
    late GoRouter router;
    router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(
          body: Column(children: [
            StreetReverseChip(type: StreetTargetType.person, id: 'le-loi'),
            StreetReverseChip(type: StreetTargetType.person, id: 'nobody'),
            StreetReverseChip(type: StreetTargetType.event, id: 'bach-dang-1288'),
          ]),
        ),
      ),
      GoRoute(path: '/duong-pho', builder: (_, __) => const Text('map-open')),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router, theme: VSTheme.build()),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('street-reverse-chip')), findsNWidgets(2));
    expect(find.textContaining('Một con đường'), findsNWidgets(2));

    await tester.tap(find.byKey(const Key('street-reverse-chip')).first);
    await tester.pump();
    await _settle(tester);
    expect(find.text('map-open'), findsOneWidget);
  });
}
