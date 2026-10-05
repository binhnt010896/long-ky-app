import 'dart:convert';
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
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;
import 'package:viet_su/app_router.dart';
import 'package:viet_su/screens/character/character_detail_screen.dart';
import 'package:viet_su/screens/streets/street_basemap.dart';
import 'package:viet_su/screens/streets/street_card.dart';
import 'package:viet_su/screens/streets/street_data.dart';
import 'package:viet_su/screens/streets/street_landmarks.dart';
import 'package:viet_su/screens/streets/street_map_screen.dart';
import 'package:viet_su/screens/streets/street_reverse_chip.dart';
import 'package:viet_su/state/providers.dart';
import 'package:viet_su/telemetry/route_telemetry.dart';
import 'package:viet_su/telemetry/telemetry.dart';


class _Collect implements vtr.Logger {
  _Collect(this.out);
  final List<String> out;
  @override
  void log(vtr.MessageFunction message) {}
  @override
  void warn(vtr.MessageFunction message) => out.add(message());
}

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

const _market = StreetLandmark(
  id: 'cho',
  name: LocalizedText(vi: 'Chợ Bến Thành', en: 'Bến Thành Market'),
  kind: LandmarkKind.market,
  lat: 10.80,
  lng: 106.70,
); // sits right on Lê Lợi
const _palace = StreetLandmark(
  id: 'dinh',
  name: LocalizedText(vi: 'Dinh Độc Lập', en: 'Independence Palace'),
  kind: LandmarkKind.palace,
  lat: 10.80,
  lng: 106.7003,
); // a few pixels from the market at zoom 13

const _mapping = StreetMapFile(
  city: 'hcm',
  osmSnapshot: 't',
  geometry: 'streets/hcm-streets.geojson',
  start: StreetStart(lat: 10.80, lng: 106.70, zoom: 13),
  landmarks: [_market, _palace],
  streets: [_le, _bach, _hidden],
);

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
  const _FakeSource({this.withData = true, this.mapping = _mapping});
  final bool withData;
  final StreetMapFile? mapping;

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

  group('basemap cache (S2)', () {
    test('a new extract version starts a fresh cache folder', () {
      expect(basemapCacheName('https://m.example/media/b.pmtiles?v=aaa'),
          '${kBasemapCacheFolder}_aaa');
      expect(basemapCacheName('https://m.example/media/b.pmtiles?v=bbb'),
          isNot(basemapCacheName('https://m.example/media/b.pmtiles?v=aaa')));
      expect(basemapCacheName('https://m.example/media/b.pmtiles'), kBasemapCacheFolder);
    });

    test('tile loading is tuned past the package defaults', () {
      expect(kBasemapConcurrency, greaterThan(4));
      expect(kBasemapTileTtl, greaterThan(const Duration(days: 30)));
    });
  });

  group('street mapping over the air (Wave E)', () {
    String shipped() => File('../../content/streets/hcm.json').readAsStringSync();

    test('the pack\'s mapping wins over the bundled one', () async {
      final fromPack = jsonDecode(shipped()) as Map<String, dynamic>;
      fromPack['osmSnapshot'] = 'from-the-pack';
      final src = BundledStreetDataSource(
          overlay: (city) async => jsonEncode(fromPack));
      final file = await src.loadMapping();
      expect(file?.osmSnapshot, 'from-the-pack');
    });

    test('no pack mapping, or one that will not read, falls back to the bundle',
        () async {
      for (final overlay in <Future<String?> Function(String)?>[
        null,
        (city) async => null,
        (city) async => 'not json',
        (city) async => throw StateError('boom'),
      ]) {
        final file = await BundledStreetDataSource(overlay: overlay).loadMapping();
        expect(file, isNotNull, reason: 'bundled mapping should be used');
        expect(file!.osmSnapshot, isNot('from-the-pack'));
        expect(file.streets, isNotEmpty);
      }
    });
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
      expect(ids, isNot(contains('places_subplace'))); // "Khu phố n" clutter
      expect(ids, contains('water'));
      expect(ids, contains('roads_highway'));
    });

    test('every label is a plain name, which the renderer understands', () {
      final warnings = <String>[];
      buildStreetBasemapTheme(logger: _Collect(warnings));
      // The stock text expressions (`format`, `is-supported-script`) are not
      // supported and would drop every label; none may be left.
      expect(warnings.where((w) => w.contains('format') || w.contains('is-supported-script')), isEmpty);
      final labels = [
        for (final l in streetBasemapLayers())
          if (l['type'] == 'symbol') l,
      ];
      expect(labels, isNotEmpty);
      for (final l in labels) {
        expect((l['layout'] as Map)['text-field'], kBasemapLabelField, reason: '${l['id']}');
      }
    });

    test('side-street names wait for zoom 16; main roads and rivers stay', () {
      final byId = {for (final l in streetBasemapLayers()) l['id']: l};
      expect(byId['roads_labels_minor']!['minzoom'], 16);
      expect(byId['roads_labels_major'], isNotNull);
      expect(byId['water_waterway_label'], isNotNull);
      expect(byId['places_locality'], isNotNull);
    });

    test('the tile cache is not the library default (it holds label-less tiles)', () {
      expect(kBasemapCacheFolder, isNot('.vector_map'));
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

  group('streetBasemapUrl', () {
    StreetMapFile file(String basemap) => StreetMapFile(
        city: 'hcm', osmSnapshot: 't', streets: const [], basemap: basemap);
    String media(String p) => 'https://cdn.test/media/$p?v=abc';

    test('comes from the mapping, through the media manifest', () {
      expect(streetBasemapUrl(file('streets/hcm-basemap.pmtiles'), override: '', mediaUrl: media),
          'https://cdn.test/media/streets/hcm-basemap.pmtiles?v=abc');
    });

    test('a build-time override wins', () {
      expect(
          streetBasemapUrl(file('streets/hcm-basemap.pmtiles'),
              override: 'http://localhost:9/x.pmtiles', mediaUrl: media),
          'http://localhost:9/x.pmtiles');
    });

    test('no basemap means none — the plain ground, not an error', () {
      expect(streetBasemapUrl(file(''), override: '', mediaUrl: media), isEmpty);
    });
  });

  test('the shipped mapping names the base map', () {
    final json = jsonDecode(File('../../content/streets/hcm.json').readAsStringSync())
        as Map<String, dynamic>;
    expect(StreetMapFile.fromJson(json).basemap, 'streets/hcm-basemap.pmtiles');
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

  group('placeLandmarks', () {
    StreetLandmark lm(String id, String vi) => StreetLandmark(
      id: id,
      name: LocalizedText(vi: vi, en: vi),
      kind: LandmarkKind.market,
      lat: 0,
      lng: 0,
    );
    double width(String t) => t.length * 6.0;
    List<LandmarkPlacement> place(
      Map<String, Offset> at,
      List<StreetLandmark> ls,
    ) => placeLandmarks(
      landmarks: ls,
      project: (l) => at[l.id]!,
      viewport: const Size(390, 800),
      lang: Lang.vi,
      measureWidth: width,
    );

    test('far apart: every badge and every label is kept', () {
      final out = place(
        {'a': const Offset(80, 200), 'b': const Offset(300, 500)},
        [lm('a', 'Chợ'), lm('b', 'Dinh')],
      );
      expect(out.map((p) => p.label != null), [true, true]);
    });

    test(
      'close together: both badges stay, the lower priority label hides',
      () {
        final out = place(
          {'a': const Offset(200, 300), 'b': const Offset(250, 300)},
          [lm('a', 'Chợ Bến Thành'), lm('b', 'Dinh Độc Lập')],
        );
        expect(out.length, 2);
        expect(out[0].label, isNotNull); // earlier in the list wins
        expect(out[1].label, isNull);
      },
    );

    test('a label never sits on another landmark\'s badge', () {
      // b's badge is right under a's label.
      final out = place(
        {'a': const Offset(200, 300), 'b': const Offset(200, 325)},
        [lm('a', 'Chợ Bến Thành'), lm('b', 'Dinh')],
      );
      expect(out[0].label, isNull);
      expect(out[1].label, isNotNull);
    });

    test('a name that would be clipped by the screen edge is hidden', () {
      final out = place({'a': const Offset(12, 300), 'b': const Offset(200, 300)},
          [lm('a', 'Sân bay Tân Sơn Nhất'), lm('b', 'Dinh')]);
      expect(out[0].badge.center, const Offset(12, 300)); // the badge stays
      expect(out[0].label, isNull);
      expect(out[1].label, isNotNull);
    });

    test('landmarks well off screen are dropped', () {
      final out = place(
        {'a': const Offset(-500, 300), 'b': const Offset(200, 300)},
        [lm('a', 'Chợ'), lm('b', 'Dinh')],
      );
      expect(out.map((p) => p.landmark.id), ['b']);
    });
  });

  testWidgets('opens on the mapping\'s start view, not the whole city', (
    tester,
  ) async {
    await _pump(tester, '/duong-pho');
    final cam = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!
        .camera;
    expect(cam.zoom, 13);
    expect(cam.center.latitude, closeTo(10.80, 1e-6));
    expect(cam.center.longitude, closeTo(106.70, 1e-6));
  });

  testWidgets('without a start view it still fits the whole locked area', (
    tester,
  ) async {
    await _pump(
      tester,
      '/duong-pho',
      source: const _FakeSource(
        mapping: StreetMapFile(
          city: 'hcm',
          osmSnapshot: 't',
          geometry: 'g',
          streets: [_le, _bach, _hidden],
        ),
      ),
    );
    final cam = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!
        .camera;
    expect(cam.zoom, lessThan(13));
  });

  testWidgets(
    'landmarks: badges drawn, names follow VI/EN, names follow VI/EN',
    (tester) async {
      final (router, _) = await _pump(tester, '/duong-pho');
      expect(find.byKey(const Key('landmark-cho')), findsOneWidget);
      expect(find.byKey(const Key('landmark-dinh')), findsOneWidget);
      // The two sit a few pixels apart: the higher-priority name wins.
      expect(find.text('Chợ Bến Thành'), findsWidgets);
      expect(find.byKey(const Key('landmark-label-cho')), findsOneWidget);
      expect(find.byKey(const Key('landmark-label-dinh')), findsNothing);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(FlutterMap)),
      );
      container.read(langProvider.notifier).state = Lang.en;
      await _settle(tester);
      expect(find.text('Bến Thành Market'), findsWidgets);
      expect(find.text('Chợ Bến Thành'), findsNothing);

      router.go('/'); // leave cleanly
    },
  );

  testWidgets('landmarks hide below zoom 11 and show from it', (tester) async {
    Widget map(double zoom) => MaterialApp(
      theme: VSTheme.build(),
      home: FlutterMap(
        key: ValueKey<double>(zoom),
        options: MapOptions(
          initialCenter: const LatLng(10.80, 106.70),
          initialZoom: zoom,
        ),
        children: const [
          StreetLandmarkLayer(landmarks: [_market], lang: Lang.vi),
        ],
      ),
    );
    await tester.pumpWidget(map(10.5));
    await tester.pump();
    expect(find.byKey(const Key('landmark-cho')), findsNothing);
    await tester.pumpWidget(map(11));
    await tester.pump();
    expect(find.byKey(const Key('landmark-cho')), findsOneWidget);
  });

  testWidgets(
    'a tap on a landmark badge falls through to the street under it',
    (tester) async {
      await _pump(tester, '/duong-pho');
      final badge = tester.getCenter(find.byKey(const Key('landmark-cho')));
      await tester.tapAt(badge);
      await _settle(tester);
      expect(
        find.byKey(const Key('street-open-person-le-loi')),
        findsOneWidget,
      );
    },
  );

  testWidgets('the search hint sits on the field\'s vertical centre', (
    tester,
  ) async {
    await _pump(tester, '/duong-pho');
    final field = tester.getRect(find.byKey(const Key('street-search')));
    final hint = tester.getRect(find.text('Tìm tên đường'));
    expect((hint.center.dy - field.center.dy).abs(), lessThanOrEqualTo(1.0));
    await tester.enterText(find.byKey(const Key('street-search')), 'bạch');
    await tester.pump();
    final typed = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('street-search')),
        matching: find.byType(EditableText),
      ),
    );
    expect((typed.center.dy - field.center.dy).abs(), lessThanOrEqualTo(1.0));
  });
}
