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
import 'package:viet_su/screens/character/standalone_character_screen.dart';
import 'package:viet_su/screens/event/standalone_event_screen.dart';
import 'package:viet_su/screens/streets/street_card.dart';
import 'package:viet_su/state/providers.dart';
import 'package:viet_su/telemetry/route_telemetry.dart';
import 'package:viet_su/telemetry/telemetry.dart';

/// The real content, plus two standalone people and a standalone event that
/// features them (Cycle R: people on no era's roster).
const String _heldId = 'nguoi-rieng-an-anh';
const String _shownId = 'nguoi-rieng-co-anh';
const String _eventId = 'su-kien-rieng-nguoi';

Map<String, dynamic> _person(String id, String name, {required bool held}) =>
    <String, dynamic>{
      'id': id,
      'name': {'vi': name, 'en': name},
      'epithet': {'vi': 'Danh sĩ thử nghiệm', 'en': 'Test scholar'},
      'bio': {'vi': 'Tiểu sử của $name.', 'en': 'Bio of $name.'},
      'lifespan': {'vi': '1650 – 1700', 'en': '1650 – 1700'},
      'avatar': held
          ? {'id': '$id-avatar', 'type': 'image', 'placeholder': 'portrait-held'}
          : {
              'id': '$id-avatar',
              'type': 'image',
              'flagship': 'people/$id/avatar.png',
              'reduced': 'people/$id/avatar.png',
            },
      'fullBody': held
          ? {'id': '$id-full', 'type': 'image', 'placeholder': 'portrait-held'}
          : {
              'id': '$id-full',
              'type': 'image',
              'flagship': 'people/$id/full.png',
              'reduced': 'people/$id/full.png',
            },
    };

class _WithStandalonePeople extends DiskContentSource {
  _WithStandalonePeople() : super(Directory('../../content'));

  @override
  Future<String> loadPeopleJson() async {
    final base = jsonDecode(await super.loadPeopleJson()) as Map<String, dynamic>;
    (base['people'] as List)
      ..add(_person(_heldId, 'Người Ẩn Ảnh', held: true))
      ..add(_person(_shownId, 'Người Có Ảnh', held: false));
    return jsonEncode(base);
  }

  @override
  Future<String> loadStandaloneEventsJson() async => jsonEncode(<String, dynamic>{
        'schemaVersion': 1,
        'events': [
          <String, dynamic>{
            'id': _eventId,
            'kind': 'historical',
            'year': {'value': 1698, 'display': {'vi': '1698', 'en': '1698'}},
            'title': {'vi': 'Sự kiện của người riêng', 'en': 'A standalone person\'s event'},
            'summary': {'vi': 'Tóm tắt.'},
            'body': {'vi': 'Nội dung.'},
            'citation': {'work': 'Đại Nam thực lục'},
            'figureIds': [_heldId, _shownId],
          },
        ],
      });
}

Future<GoRouter> _pump(WidgetTester tester, String location) async {
  final container = ProviderContainer(overrides: [
    contentRepositoryProvider
        .overrideWithValue(ContentRepository(_WithStandalonePeople())),
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
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return router;
}

String _location(GoRouter r) =>
    r.routerDelegate.currentConfiguration.uri.toString();

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390, 1200);
    view.devicePixelRatio = 1.0;
  });

  group('/nhan-vat/:id', () {
    testWidgets('a standalone person opens their own page', (tester) async {
      final router = await _pump(tester, '/nhan-vat/$_shownId');
      expect(_location(router), '/nhan-vat/$_shownId');
      expect(find.byType(StandaloneCharacterScreen), findsOneWidget);
      expect(find.text('Người Có Ảnh'), findsOneWidget);
      expect(find.text('Tiểu sử của Người Có Ảnh.'), findsOneWidget);
      expect(find.text('1650 – 1700'), findsOneWidget);
      expect(find.byKey(const Key('standalone-portrait')), findsOneWidget);
    });

    testWidgets('a held portrait leaves out the portrait block', (tester) async {
      await _pump(tester, '/nhan-vat/$_heldId');
      expect(find.text('Người Ẩn Ảnh'), findsOneWidget);
      expect(find.byKey(const Key('standalone-portrait')), findsNothing);
    });

    testWidgets('a person on a roster is redirected to their era page',
        (tester) async {
      final router = await _pump(tester, '/nhan-vat/le-loi');
      expect(_location(router), startsWith('/era/'));
      expect(_location(router), endsWith('/figure/le-loi'));
      expect(find.byType(CharacterDetailScreen), findsOneWidget);
      expect(find.byType(StandaloneCharacterScreen), findsNothing);
    });

    testWidgets('an unknown id says so instead of failing', (tester) async {
      await _pump(tester, '/nhan-vat/khong-co-nguoi-nay');
      expect(find.text('Không tìm thấy nhân vật'), findsOneWidget);
    });

    testWidgets('lists the standalone events the person appears in',
        (tester) async {
      await _pump(tester, '/nhan-vat/$_heldId');
      expect(find.text('XUẤT HIỆN TRONG'), findsOneWidget);
      expect(find.text('Sự kiện của người riêng'), findsOneWidget);
    });
  });

  testWidgets('a standalone event\'s chip opens the standalone person',
      (tester) async {
    await _pump(tester, '/su-kien/$_eventId');
    expect(find.byType(StandaloneEventScreen), findsOneWidget);
    final chip = find.text('Người Ẩn Ảnh');
    expect(chip, findsOneWidget);
    await tester.ensureVisible(chip);
    Scrollable.ensureVisible(tester.element(chip), alignment: 0.5);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(chip);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final page = tester
        .widget<StandaloneCharacterScreen>(find.byType(StandaloneCharacterScreen));
    expect(page.figureId, _heldId);
  });

  test('routeForTarget: a person with no era opens by id alone', () {
    expect(
      routeForTarget(const StreetTarget(
          type: StreetTargetType.person, id: 'nguyen-huu-canh', era: '')),
      '/nhan-vat/nguyen-huu-canh',
    );
    expect(
      routeForTarget(const StreetTarget(
          type: StreetTargetType.person, id: 'le-loi', era: 'le-loi')),
      '/era/le-loi/figure/le-loi',
    );
  });

  test('telemetry: /nhan-vat/:id logs figure_detail with the id only', () {
    final v = mapUriToScreen(Uri.parse('/nhan-vat/$_shownId'))!;
    expect(v.name, 'figure_detail');
    expect(v.params, {'figure_id': _shownId});
    expect(mapUriToScreen(Uri.parse('/nhan-vat')), isNull);
  });
}
