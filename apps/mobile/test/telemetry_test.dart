import 'dart:convert';
import 'dart:io';

import 'package:core_content/core_content.dart';
import 'package:core_content/testing.dart';
import 'package:core_domain/core_domain.dart';
import 'package:executor_lib/executor_lib.dart' show CancellationException;
import 'package:experience/experience.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:viet_su/app_router.dart';
import 'package:viet_su/screens/home/home_screen.dart';
import 'package:viet_su/state/content_sync.dart';
import 'package:viet_su/state/narration_controller.dart';
import 'package:viet_su/state/providers.dart';
import 'package:viet_su/state/quiz_store.dart';
import 'package:viet_su/state/reminder_service.dart';
import 'package:viet_su/state/tip_store.dart';
import 'package:viet_su/state/today_store.dart';
import 'package:viet_su/state/visit_store.dart';
import 'package:viet_su/telemetry/composite_telemetry.dart';
import 'package:viet_su/telemetry/route_telemetry.dart';
import 'package:viet_su/telemetry/telemetry.dart';
import 'package:viet_su/telemetry/telemetry_settings.dart';

import 'memory_stores.dart';

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

  final Map<String, Object> common = <String, Object>{};

  @override
  Future<void> setCommonProperty(String key, Object value) async =>
      common[key] = value;

  /// The params of every `screen_leave` logged so far.
  List<Map<String, Object>> get leaves => <Map<String, Object>>[
        for (final e in events)
          if (e.name == 'screen_leave') e.params,
      ];
}

/// A backend whose every call fails — [CompositeTelemetry] must shrug it off.
class _ThrowingTelemetry implements Telemetry {
  @override
  Future<void> screen(String name, [Map<String, Object> params = const {}]) =>
      throw StateError('screen');
  @override
  Future<void> event(String name, [Map<String, Object> params = const {}]) async =>
      throw StateError('event');
  @override
  Future<void> recordError(Object error, StackTrace stackTrace,
          {String? reason, bool fatal = false}) =>
      throw StateError('recordError');
  @override
  Future<void> setEnabled(bool enabled) async => throw StateError('setEnabled');
  @override
  Future<void> setCommonProperty(String key, Object value) =>
      throw StateError('setCommonProperty');
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
    List<bool>? marks,
  }) async {
    _progress = _progress.withResult(modeKey, score, total,
        markDailyDoneOn: dailyOn, marks: marks);
    return _progress;
  }
}


Era _loadEra(String slug) {
  final people = PeopleRegistry.fromJson(
      jsonDecode(File('../../content/people.json').readAsStringSync())
          as Map<String, dynamic>);
  final events = EventRegistry.fromJson(
      jsonDecode(File('../../content/events.json').readAsStringSync())
          as Map<String, dynamic>);
  return Era.fromJson(
      jsonDecode(File('../../content/eras/$slug.json').readAsStringSync())
          as Map<String, dynamic>,
      people,
      events);
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
  DateTime Function()? clock,
}) async {
  final container = ProviderContainer(overrides: <Override>[
    tierProvider.overrideWithValue(ExperienceTier.reduced),
    contentRepositoryProvider.overrideWithValue(ContentRepository(DiskContentSource(Directory('../../content')))),
    tipStoreProvider.overrideWithValue(null),
    quizStoreProvider.overrideWithValue(quizStore ?? _MemoryQuizStore()),
    activeContentVersionProvider.overrideWith((ref) => 0),
    telemetryProvider.overrideWithValue(telemetry),
    // Never touch path_provider or the notifications plugin from a widget test.
    visitStoreProvider.overrideWithValue(MemoryVisitStore()),
    narrationStoreProvider.overrideWithValue(MemoryNarrationStore()),
    todayStoreProvider.overrideWithValue(MemoryTodayStore()),
    reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
    if (clock != null) telemetryClockProvider.overrideWithValue(clock),
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
      expectScreen(mapUriToScreen(Uri.parse('/duong-pho')), 'street_map',
          const <String, Object>{});
      expectScreen(mapUriToScreen(Uri.parse('/duong-pho?street=le-loi')),
          'street_map', const <String, Object>{'street_id': 'le-loi'});
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
      // "Hôm nay" always redirects to the page it picked, but every route is mapped.
      expectScreen(
          mapUriToScreen(Uri.parse('/hom-nay')), 'today', const <String, Object>{});
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

      // screen_leave (the route the pump started from) is not a quiz event.
      bool isQuiz(String n) => n.startsWith('quiz_');
      expect(telemetry.events.map((e) => e.name).where(isQuiz),
          <String>['quiz_start']);

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

      final names = telemetry.events.map((e) => e.name).where(isQuiz).toList();
      expect(names.first, 'quiz_start');
      expect(names.last, 'quiz_complete');
      expect(names.where((n) => n == 'quiz_answer').length, answered);
    });
  });

  group('error classification', () {
    test('tile cancellations are benign; real errors are not', () {
      expect(isBenignError(CancellationException()), isTrue);
      expect(isBenignError(StateError('boom')), isFalse);
      expect(isBenignError(const SocketException('reset')), isFalse);
    });

    test('image-load failures are non-fatal; other Flutter errors are fatal', () {
      const image = FlutterErrorDetails(
        exception: SocketException('reset'),
        library: 'image resource service',
      );
      final other = FlutterErrorDetails(
        exception: StateError('boom'),
        library: 'widgets library',
      );
      expect(isNonFatalFlutterError(image), isTrue);
      expect(isNonFatalFlutterError(other), isFalse);
    });
  });

  group('screen_leave (time on screen)', () {
    testWidgets('navigating away logs the previous screen and its time',
        (tester) async {
      final telemetry = _FakeTelemetry();
      var now = DateTime(2026, 10, 23);
      final router =
          await _pumpAt(tester, '/sanh', telemetry, clock: () => now);

      now = now.add(const Duration(seconds: 7));
      router.go('/sanh/gioi-thieu');
      await tester.pumpAndSettle();

      final leave = telemetry.leaves.last;
      expect(leave['screen'], 'sanh');
      expect(leave['duration_ms'], 7000);
      expect(leave['reason'], 'navigate');
    });

    testWidgets('backgrounding reports the screen and pauses the timing',
        (tester) async {
      final telemetry = _FakeTelemetry();
      var now = DateTime(2026, 10, 23);
      final router =
          await _pumpAt(tester, '/sanh', telemetry, clock: () => now);
      final observer = ProviderScope.containerOf(
              tester.element(find.byType(MaterialApp)),
              listen: false)
          .read(routeTelemetryObserverProvider);
      final screensBefore = telemetry.screens.length;

      now = now.add(const Duration(seconds: 3));
      observer.appLifecycleChanged(AppLifecycleState.inactive);
      observer.appLifecycleChanged(AppLifecycleState.hidden);
      observer.appLifecycleChanged(AppLifecycleState.paused);
      expect(telemetry.leaves.last['screen'], 'sanh');
      expect(telemetry.leaves.last['duration_ms'], 3000);
      expect(telemetry.leaves.last['reason'], 'background');
      final leavesInBackground = telemetry.leaves.length;

      now = now.add(const Duration(minutes: 30)); // in the background
      observer.appLifecycleChanged(AppLifecycleState.resumed);
      now = now.add(const Duration(seconds: 2));
      router.go('/sanh/gioi-thieu');
      await tester.pumpAndSettle();

      expect(telemetry.leaves.length, leavesInBackground + 1);
      expect(telemetry.leaves.last['screen'], 'sanh');
      expect(telemetry.leaves.last['duration_ms'], 2000);
      // Only the About page was a new screen view — not the resume.
      expect(telemetry.screens.length, screensBefore + 1);
      expect(telemetry.screens.last.name, 'about');
    });
  });

  group('event pager', () {
    const path = '/era/hong-bang-van-lang/event/kinh-duong-vuong-lap-nuoc';

    testWidgets('a swipe logs the swiped-to event as its own screen view',
        (tester) async {
      final telemetry = _FakeTelemetry();
      var now = DateTime(2026, 10, 23);
      final router = await _pumpAt(tester, path, telemetry, clock: () => now);

      now = now.add(const Duration(seconds: 20));
      await tester.fling(find.byType(PageView), const Offset(-360, 0), 1000);
      await tester.pumpAndSettle();

      final swiped = telemetry.screens.last;
      expect(swiped.name, 'event_detail');
      expect(swiped.params['era_slug'], 'hong-bang-van-lang');
      expect(swiped.params['via'], 'swipe');
      final swipedId = swiped.params['event_id'];
      expect(swipedId, isNot('kinh-duong-vuong-lap-nuoc'));

      final left = telemetry.leaves.last;
      expect(left['event_id'], 'kinh-duong-vuong-lap-nuoc');
      expect(left['reason'], 'swipe');
      expect(left['duration_ms'], 20000);

      // Leaving the pager closes out the swiped-to event, not the opener.
      router.go('/');
      await tester.pumpAndSettle();
      expect(telemetry.leaves.last['event_id'], swipedId);
    });

    testWidgets('reading depth and "Đọc thêm" ride on the event screen_leave',
        (tester) async {
      final telemetry = _FakeTelemetry();
      final router = await _pumpAt(tester, path, telemetry);

      await tester.tap(find.text('ĐỌC THÊM'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, -5000));
      await tester.pumpAndSettle();
      router.go('/');
      await tester.pumpAndSettle();

      final leave = telemetry.leaves
          .lastWhere((l) => l['screen'] == 'event_detail');
      expect(leave['details_opened'], 1);
      expect(leave['max_scroll_pct'], 100);
    });
  });

  group('common properties', () {
    test('lang and content_version are set up front and follow changes',
        () async {
      final telemetry = _FakeTelemetry();
      final container = ProviderContainer(overrides: <Override>[
        telemetryProvider.overrideWithValue(telemetry),
        activeContentVersionProvider.overrideWith((ref) => 41),
      ]);
      addTearDown(container.dispose);

      container.read(telemetryCommonPropertiesProvider);
      expect(telemetry.common, <String, Object>{'lang': 'vi', 'content_version': 41});

      container.read(langProvider.notifier).state = Lang.en;
      container.read(activeContentVersionProvider.notifier).state = 42;
      expect(telemetry.common, <String, Object>{'lang': 'en', 'content_version': 42});
    });
  });

  group('CompositeTelemetry', () {
    test('every call reaches every backend, even past one that throws',
        () async {
      final a = _FakeTelemetry();
      final b = _FakeTelemetry();
      final both = CompositeTelemetry(<Telemetry>[a, _ThrowingTelemetry(), b]);

      await both.screen('home');
      await both.event('quiz_start', <String, Object>{'quiz_mode': 'daily'});
      await both.setCommonProperty('lang', 'vi');
      await both.setEnabled(false);
      await both.recordError(StateError('x'), StackTrace.empty);

      for (final t in <_FakeTelemetry>[a, b]) {
        expect(t.screens.single.name, 'home');
        expect(t.events.single.name, 'quiz_start');
        expect(t.events.single.params, <String, Object>{'quiz_mode': 'daily'});
        expect(t.common, <String, Object>{'lang': 'vi'});
        expect(t.enabled, isFalse);
      }
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
