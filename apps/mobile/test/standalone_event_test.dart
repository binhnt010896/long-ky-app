import 'dart:convert';
import 'dart:io';

import 'package:core_content/core_content.dart';
import 'package:core_content/testing.dart';
import 'package:core_domain/core_domain.dart';
import 'package:experience/experience.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:viet_su/app_router.dart';
import 'package:viet_su/screens/character/character_detail_screen.dart';
import 'package:viet_su/screens/event/event_detail_screen.dart';
import 'package:viet_su/screens/event/standalone_event_screen.dart';
import 'package:viet_su/screens/timeline/standalone_placement.dart';
import 'package:viet_su/state/providers.dart';
import 'package:viet_su/telemetry/route_telemetry.dart';
import 'package:viet_su/telemetry/telemetry.dart';

/// The real content, plus one standalone event the real content doesn't have
/// yet (there are none until one is authored in the CMS).
const String _aloneId = 'su-kien-rieng-thu-nghiem';
const String _aloneFigure = 'le-loi';
const String _inEraEventId = 'trieu-vu-de-lap-nam-viet';

class _WithStandalone extends DiskContentSource {
  _WithStandalone() : super(Directory('../../content'));

  @override
  Future<String> loadStandaloneEventsJson() async => jsonEncode(<String, dynamic>{
        'schemaVersion': 1,
        'events': [
          <String, dynamic>{
            'id': _aloneId,
            'kind': 'historical',
            // Between two eras' starts, so the timeline has somewhere to put it.
            'year': {'value': 1500, 'display': {'vi': '1500', 'en': '1500'}},
            'title': {'vi': 'Sự kiện thử nghiệm riêng', 'en': 'A standalone test event'},
            'summary': {'vi': 'Tóm tắt.'},
            'body': {'vi': 'Nội dung của sự kiện riêng.'},
            'citation': {'work': 'Đại Việt sử ký toàn thư'},
            'figureIds': [_aloneFigure],
          },
        ],
      });
}

Future<(GoRouter, ProviderContainer)> _pump(
    WidgetTester tester, String location) async {
  final container = ProviderContainer(overrides: [
    contentRepositoryProvider.overrideWithValue(ContentRepository(_WithStandalone())),
    telemetryProvider.overrideWithValue(const NoopTelemetry()),
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
  // Each async hop (redirect, content futures) needs its own frame.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return (router, container);
}

/// Scrolls [finder] to the middle of the screen. The bare `ensureVisible`
/// parks it at the top edge, under the floating top bar, where a tap would
/// land on the bar instead.
Future<void> _centre(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pump(const Duration(milliseconds: 400));
}

String _location(GoRouter r) =>
    r.routerDelegate.currentConfiguration.uri.toString();

/// The earliest era (by order) whose roster lists [personId].
String _homeEra(String personId) {
  final root = Directory('../../content/eras');
  Map<String, dynamic>? best;
  for (final f in root.listSync().whereType<File>().where((f) => f.path.endsWith('.json'))) {
    final era = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final onRoster = (era['characters'] as List).any((c) => (c as Map)['ref'] == personId);
    if (onRoster && (best == null || (era['order'] as int) < (best['order'] as int))) {
      best = era;
    }
  }
  return best!['slug'] as String;
}

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390, 1200);
    view.devicePixelRatio = 1.0;
  });

  group('/su-kien/:id', () {
    testWidgets('an event that sits in an era is redirected to its era route',
        (tester) async {
      final (router, _) = await _pump(tester, '/su-kien/$_inEraEventId');
      expect(_location(router), '/era/nha-trieu/event/$_inEraEventId');
      expect(find.byType(EventDetailScreen), findsOneWidget);
      expect(find.byType(StandaloneEventScreen), findsNothing);
    });

    testWidgets('a standalone event opens its own page, marked as standalone',
        (tester) async {
      final (router, _) = await _pump(tester, '/su-kien/$_aloneId');
      expect(_location(router), '/su-kien/$_aloneId');
      expect(find.byType(StandaloneEventScreen), findsOneWidget);
      expect(find.text('Sự kiện thử nghiệm riêng'), findsOneWidget);
      expect(find.text('Nội dung của sự kiện riêng.'), findsOneWidget);
      expect(find.text(StandaloneEventScreen.viLabel), findsOneWidget);
      // No era pager: no "03 / 12" counter.
      expect(find.textContaining(RegExp(r'^\d\d / \d\d$')), findsNothing);
    });

    testWidgets('a figure chip opens the person in their home era', (tester) async {
      final (router, _) = await _pump(tester, '/su-kien/$_aloneId');
      final chip = find.textContaining('Lê Lợi').first;
      await _centre(tester, chip);
      await tester.tap(chip);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // `push` leaves currentConfiguration.uri on the base location, so check
      // what is actually on screen: that figure's page, under their home era.
      expect(router, isNotNull);
      final page = tester.widget<CharacterDetailScreen>(find.byType(CharacterDetailScreen));
      expect(page.slug, _homeEra(_aloneFigure));
      expect(page.figureId, _aloneFigure);
    });

    testWidgets('an unknown id says so instead of failing', (tester) async {
      await _pump(tester, '/su-kien/khong-co-su-kien-nay');
      expect(find.text('Không tìm thấy sự kiện này.'), findsOneWidget);
    });
  });

  group('global timeline', () {
    testWidgets('a standalone event is its own node, marked "Sự kiện riêng"',
        (tester) async {
      await _pump(tester, '/timeline');
      final node = find.text('Sự kiện thử nghiệm riêng');
      await tester.scrollUntilVisible(node, 600,
          scrollable: find.byType(Scrollable).first);
      expect(node, findsOneWidget);
      expect(find.text('Sự kiện riêng'), findsWidgets);
    });

    testWidgets('search finds a standalone event by its title, unaccented',
        (tester) async {
      await _pump(tester, '/timeline');
      await tester.enterText(find.byType(TextField), 'thu nghiem rieng');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Sự kiện thử nghiệm riêng'), findsOneWidget);
    });

    testWidgets('tapping the node opens /su-kien/:id', (tester) async {
      final (router, _) = await _pump(tester, '/timeline');
      final node = find.text('Sự kiện thử nghiệm riêng');
      await tester.scrollUntilVisible(node, 600,
          scrollable: find.byType(Scrollable).first);
      await _centre(tester, node);
      await tester.tap(node);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // (`push`: check the screen, not currentConfiguration.uri.)
      expect(router, isNotNull);
      final page = tester.widget<StandaloneEventScreen>(find.byType(StandaloneEventScreen));
      expect(page.eventId, _aloneId);
    });
  });

  testWidgets('the Character page lists standalone events featuring the person',
      (tester) async {
    await _pump(tester, '/era/${_homeEra(_aloneFigure)}/figure/$_aloneFigure');
    final label = find.text('CŨNG XUẤT HIỆN TRONG');
    await tester.scrollUntilVisible(label, 400,
        scrollable: find.byType(Scrollable).first);
    expect(label, findsOneWidget);
    expect(find.text('Sự kiện thử nghiệm riêng'), findsOneWidget);
  });

  test('telemetry: /su-kien/:id logs event_detail with the event id only', () {
    final v = mapUriToScreen(Uri.parse('/su-kien/$_aloneId'))!;
    expect(v.name, 'event_detail');
    expect(v.params, {'event_id': _aloneId});
    expect(mapUriToScreen(Uri.parse('/su-kien')), isNull);
  });

  group('StandalonePlacement (decision N6)', () {
    Era era(String slug, int start) => Era.fromJson(<String, dynamic>{
          'schemaVersion': 1,
          'id': slug,
          'slug': slug,
          'order': start,
          'title': {'vi': slug},
          'kicker': {'vi': slug},
          'subtitle': {'vi': slug},
          'yearRange': {'display': {'vi': '$start'}, 'startYear': start},
          'palette': {'accent': '#b8322a'},
          'primarySource': {'work': 'x'},
          'events': <dynamic>[],
        }, PeopleRegistry.empty);

    HistoryEvent event(String id, int? year) => HistoryEvent.fromJson(<String, dynamic>{
          'id': id,
          'order': 0,
          'kind': 'historical',
          'year': {
            if (year != null) 'value': year,
            'display': {'vi': '${year ?? '?'}'},
          },
          'title': {'vi': id},
          'summary': {'vi': id},
          'citation': {'work': 'x'},
        });

    final eras = [era('a', -500), era('b', 0), era('c', 1000)];

    test('goes right after the era whose startYear is the latest one <= its year', () {
      final p = StandalonePlacement.place(eras, [event('x', 500), event('y', 1000), event('z', 1500)]);
      expect(p.afterEra[1]!.map((e) => e.id), ['x']); // 0 <= 500 < 1000
      expect(p.afterEra[2]!.map((e) => e.id), ['y', 'z']); // 1000 <= both
      expect(p.beforeFirst, isEmpty);
    });

    test('an event earlier than every era goes before the first group', () {
      final p = StandalonePlacement.place(eras, [event('old', -900)]);
      expect(p.beforeFirst.map((e) => e.id), ['old']);
      expect(p.afterEra, isEmpty);
    });

    test('several in one group are sorted by year', () {
      final p = StandalonePlacement.place(eras, [event('late', 900), event('early', 100)]);
      expect(p.afterEra[1]!.map((e) => e.id), ['early', 'late']);
    });

    test('an undated event is left out rather than guessed at', () {
      final p = StandalonePlacement.place(eras, [event('u', null)]);
      expect(p.beforeFirst, isEmpty);
      expect(p.afterEra, isEmpty);
    });

    test('a later era wins a tie on startYear', () {
      final tied = [era('first', 100), era('second', 100)];
      final p = StandalonePlacement.place(tied, [event('t', 150)]);
      expect(p.afterEra.keys, [1]);
    });
  });
}
