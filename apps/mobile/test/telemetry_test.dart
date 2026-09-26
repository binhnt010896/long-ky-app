import 'dart:convert';
import 'dart:io';

import 'package:core_content/core_content.dart';
import 'package:core_domain/core_domain.dart';
import 'package:experience/experience.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:viet_su/app_router.dart';
import 'package:viet_su/screens/home/home_screen.dart';
import 'package:viet_su/state/content_sync.dart';
import 'package:viet_su/state/providers.dart';
import 'package:viet_su/state/quiz_store.dart';
import 'package:viet_su/state/tip_store.dart';
import 'package:viet_su/telemetry/route_telemetry.dart';
import 'package:viet_su/telemetry/telemetry.dart';
import 'package:viet_su/telemetry/telemetry_settings.dart';

/// Records every call instead of sending anything anywhere — the seam every
/// telemetry test in this file asserts against.
class _FakeTelemetry implements Telemetry {
  final List<({String name, Map<String, Object> params})> screens =
      <({String name, Map<String, Object> params})>[];
  final List<({String name, Map<String, Object> params})> events =
      <({String name, Map<String, Object> params})>[];
  bool enabled = true;

  @override
  Future<void> screen(String name, [Map<String, Object> params = const {}]) async {
    screens.add((name: name, params: params));
  }

  @override
  Future<void> event(String name, [Map<String, Object> params = const {}]) async {
    events.add((name: name, params: params));
  }

  @override
  Future<void> recordError(Object error, StackTrace stackTrace,
      {String? reason, bool fatal = false}) async {}

  @override
  Future<void> setEnabled(bool value) async => enabled = value;
}

class _MemoryTelemetrySettingsStore implements TelemetrySettingsStore {
  bool _enabled = true;
  @override
  Future<bool> load() async => _enabled;
  @override
  Future<void> setEnabled(bool enabled) async => _enabled = enabled;
}

/// An in-memory quiz store, mirroring era_screens_test.dart's fake — avoids
/// touching `path_provider`, which is unmocked in widget tests.
class _MemoryQuizStore implements QuizStore {
  QuizProgress _progress = QuizProgress.empty;

  @override
  Future<QuizProgress> load() async => _progress;

  @override
  Future<QuizProgress> recordResult({
    required String modeKey,
    required int score,
    required int total,
    DateTime? dailyOn,
  }) async {
    _progress =
        _progress.withResult(modeKey, score, total, markDailyDoneOn: dailyOn);
    return _progress;
  }
}

/// Content source backed by the repo's real content/ directory on disk —
/// mirrors era_screens_test.dart's `_DiskSource` (the quiz generator needs
/// the full corpus to reliably produce 5 daily questions at seed=1, exactly
/// as that file's own quiz tests rely on).
class _DiskSource implements ContentSource {
  @override
  Future<List<String>> availableSlugs() async => <String>[
        'hong-bang-van-lang',
        'au-lac',
        'nha-trieu',
        'hai-ba-trung',
        'ba-trieu',
        'van-xuan',
        'mai-hac-de',
        'phung-hung',
        'khuc-thua-du',
        'ngo-quyen',
        'dinh-tien-hoang',
        'tien-le',
        'ly-thai-to',
        'ly-thai-tong',
        'ly-nhan-tong',
        'tran-thai-tong',
        'tran-hung-dao',
        'le-loi',
        'le-thanh-tong',
        'nam-bac-trieu',
        'trinh-nguyen',
        'tay-son',
        'gia-long',
        'minh-mang',
        'thieu-tri',
        'tu-duc',
        'can-vuong',
        'phong-trao-yeu-nuoc',
        'cach-mang-thang-tam',
        'dien-bien-phu',
        'dai-thang-mua-xuan',
        'thong-nhat-dat-nuoc',
        'bien-gioi-tay-nam',
        'bien-gioi-phia-bac',
        'cong-cuoc-doi-moi',
        'hoi-nhap-quoc-te',
        'vi-the-moi',
        'ky-nguyen-vuon-minh',
      ];

  @override
  Future<String> loadEraJson(String slug) async =>
      File('../../content/eras/$slug.json').readAsStringSync();

  @override
  Future<String> loadPeopleJson() async =>
      File('../../content/people.json').readAsStringSync();

  @override
  Future<String> loadPeriodsJson() async =>
      File('../../content/periods.json').readAsStringSync();
}

Era _loadEra(String slug) {
  final people = PeopleRegistry.fromJson(
      jsonDecode(File('../../content/people.json').readAsStringSync())
          as Map<String, dynamic>);
  return Era.fromJson(
      jsonDecode(File('../../content/eras/$slug.json').readAsStringSync())
          as Map<String, dynamic>,
      people);
}

Period _loadPeriod(String id) {
  final registry = PeriodRegistry.fromJson(
      jsonDecode(File('../../content/periods.json').readAsStringSync())
          as Map<String, dynamic>);
  return registry[id]!;
}

/// Pumps the real router (so navigation matches app_router.dart exactly) with
/// [telemetry] wired in as both the read seam and the live route observer —
/// mirrors era_screens_test.dart's `_pumpAt`, plus the telemetry override.
Future<GoRouter> _pumpAt(
  WidgetTester tester,
  String location,
  _FakeTelemetry telemetry, {
  QuizStore? quizStore,
}) async {
  final container = ProviderContainer(overrides: <Override>[
    tierProvider.overrideWithValue(ExperienceTier.reduced),
    contentRepositoryProvider.overrideWithValue(ContentRepository(_DiskSource())),
    tipStoreProvider.overrideWithValue(null),
    quizStoreProvider.overrideWithValue(quizStore ?? _MemoryQuizStore()),
    activeContentVersionProvider.overrideWith((ref) => 0),
    telemetryProvider.overrideWithValue(telemetry),
  ]);
  addTearDown(container.dispose);

  final router = container.read(routerProvider);
  container.read(routeTelemetryObserverProvider); // attach the listener

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ExperienceScope(
        tier: ExperienceTier.reduced,
        child: MaterialApp.router(routerConfig: router, theme: VSTheme.build()),
      ),
    ),
  );
  await tester.pump();
  router.go(location);
  await tester.pump();
  await tester.pumpAndSettle();
  return router;
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

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  // Records with Map fields don't compare equal via plain `==` (Map isn't
  // content-equal), so assert name/params separately rather than on the
  // whole record.
  void expectScreen(ScreenView? actual, String name, Map<String, Object> params) {
    expect(actual, isNotNull);
    expect(actual!.name, name);
    expect(actual.params, equals(params));
  }

  group('mapUriToScreen', () {
    test('covers every route in app_router.dart', () {
      expectScreen(mapUriToScreen(Uri.parse('/')), 'home', const <String, Object>{});
      expectScreen(mapUriToScreen(Uri.parse('/timeline')), 'global_timeline',
          const <String, Object>{});
      expectScreen(
          mapUriToScreen(Uri.parse('/map')), 'atlas', const <String, Object>{});
      expectScreen(mapUriToScreen(Uri.parse('/map?era=au-lac')), 'atlas',
          const <String, Object>{'era_slug': 'au-lac'});
      expectScreen(
          mapUriToScreen(Uri.parse('/sanh')), 'sanh', const <String, Object>{});
      expectScreen(mapUriToScreen(Uri.parse('/sanh/gioi-thieu')), 'about',
          const <String, Object>{});
      expectScreen(mapUriToScreen(Uri.parse('/sanh/cau-do')), 'quiz_home',
          const <String, Object>{});
      expectScreen(
          mapUriToScreen(Uri.parse('/sanh/cau-do/choi?mode=daily&seed=1')),
          'quiz_play',
          const <String, Object>{'quiz_mode': 'daily'});
      expectScreen(
          mapUriToScreen(Uri.parse('/chao-co')), 'chao_co', const <String, Object>{});
      expectScreen(mapUriToScreen(Uri.parse('/era/au-lac')), 'era_hub',
          const <String, Object>{'era_slug': 'au-lac'});
      expectScreen(mapUriToScreen(Uri.parse('/era/au-lac/timeline')), 'era_timeline',
          const <String, Object>{'era_slug': 'au-lac'});
      expectScreen(
          mapUriToScreen(Uri.parse('/era/au-lac/event/thuc-phan-xung-vuong')),
          'event_detail',
          const <String, Object>{
            'era_slug': 'au-lac',
            'event_id': 'thuc-phan-xung-vuong',
          });
      expectScreen(
          mapUriToScreen(Uri.parse('/era/au-lac/figure/an-duong-vuong')),
          'figure_detail',
          const <String, Object>{
            'era_slug': 'au-lac',
            'figure_id': 'an-duong-vuong',
          });
    });

    test('returns null for an unrecognised location', () {
      expect(mapUriToScreen(Uri.parse('/nonexistent')), isNull);
    });
  });

  group('screen_view logging', () {
    testWidgets('Home → Era Hub → Event logs each screen, in order',
        (tester) async {
      final telemetry = _FakeTelemetry();
      final router = await _pumpAt(tester, '/', telemetry);

      expect(telemetry.screens.map((s) => s.name), contains('home'));

      // Drive navigation the same way the app itself does (context.push from
      // inside a route/screen ultimately calls this) — go() is what the test
      // harness's own _pumpAt uses to reach the very first location, and is
      // exercised the same way throughout era_screens_test.dart.
      router.go('/era/au-lac');
      await tester.pumpAndSettle();
      expectScreen(telemetry.screens.last, 'era_hub',
          const <String, Object>{'era_slug': 'au-lac'});

      // Every event in au-lac.json shares the same era, so any first event id
      // is fine here — this test cares about the screen name/params, not
      // which specific event.
      final era = _loadEra('au-lac');
      final eventId = era.events.first.id;
      router.go('/era/au-lac/event/$eventId');
      await tester.pumpAndSettle();
      expectScreen(telemetry.screens.last, 'event_detail',
          <String, Object>{'era_slug': 'au-lac', 'event_id': eventId});

      // Re-entering era_hub must log again, not be treated as "already seen".
      router.go('/era/au-lac');
      await tester.pumpAndSettle();
      expectScreen(telemetry.screens.last, 'era_hub',
          const <String, Object>{'era_slug': 'au-lac'});
    });
  });

  group('era_card_view (Home)', () {
    testWidgets('a fast multi-page swipe logs exactly one debounced event',
        (tester) async {
      final telemetry = _FakeTelemetry();
      final dynasty = Dynasty(
        period: _loadPeriod('hong-bang'),
        eras: <Era>[_loadEra('hong-bang-van-lang'), _loadEra('au-lac')],
      );
      final container = ProviderContainer(overrides: <Override>[
        tierProvider.overrideWithValue(ExperienceTier.reduced),
        dynastiesProvider.overrideWith((ref) async => <Dynasty>[dynasty]),
        telemetryProvider.overrideWithValue(telemetry),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ExperienceScope(
                tier: ExperienceTier.reduced, child: HomeScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // Swipe twice in quick succession (no settle in between) — only the
      // era it lands on should be counted.
      final horizontalPager = find.byWidgetPredicate(
          (w) => w is PageView && w.scrollDirection == Axis.horizontal);
      await tester.fling(horizontalPager, const Offset(-400, 0), 1200);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Not yet — still inside the 1s debounce window.
      expect(telemetry.events, isEmpty);

      await tester.pump(const Duration(seconds: 1));
      expect(telemetry.events.length, 1);
      expect(telemetry.events.single.name, 'era_card_view');
      expect(telemetry.events.single.params['era_slug'], 'au-lac');
      expect(telemetry.events.single.params['period_id'], 'hong-bang');
    });
  });

  group('quiz event logging', () {
    testWidgets(
        'a full daily quiz (seed 1) logs quiz_start, one quiz_answer per '
        'question, then quiz_complete', (tester) async {
      final telemetry = _FakeTelemetry();
      await _pumpAt(tester, '/sanh/cau-do/choi?mode=daily&seed=1', telemetry);

      expect(telemetry.events.map((e) => e.name), <String>['quiz_start']);

      var answered = 0;
      for (var q = 0; q < 5; q++) {
        for (var i = 0; i < 4; i++) {
          final tile = find.byKey(ValueKey<int>(i));
          if (tile.evaluate().isEmpty) break;
          await tester.tap(tile);
          await tester.pump();
          if (find.text('Tiếp theo ›').evaluate().isNotEmpty) break;
        }
        await tester.pumpAndSettle();
        answered++;
        final next = find.text('Tiếp theo ›');
        if (next.evaluate().isNotEmpty) {
          await tester.ensureVisible(next);
          await tester.pumpAndSettle();
          await tester.tap(next);
          await tester.pumpAndSettle();
        }
      }

      final names = telemetry.events.map((e) => e.name).toList();
      expect(names.first, 'quiz_start');
      expect(names.last, 'quiz_complete');
      expect(names.where((n) => n == 'quiz_answer').length, answered);
    });
  });

  group('telemetryEnabledProvider', () {
    test('defaults on, persists an off choice, and disables Telemetry too',
        () async {
      final telemetry = _FakeTelemetry();
      final store = _MemoryTelemetrySettingsStore();
      final container = ProviderContainer(overrides: <Override>[
        telemetryProvider.overrideWithValue(telemetry),
        telemetrySettingsStoreProvider.overrideWithValue(store),
      ]);
      addTearDown(container.dispose);

      expect(await container.read(telemetryEnabledProvider.future), isTrue);

      await container.read(telemetryEnabledProvider.notifier).setEnabled(false);
      expect(container.read(telemetryEnabledProvider).valueOrNull, isFalse);
      expect(telemetry.enabled, isFalse);
      expect(await store.load(), isFalse);
    });
  });
}
