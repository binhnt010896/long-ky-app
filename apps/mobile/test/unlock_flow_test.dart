import 'dart:io';

import 'package:core_content/core_content.dart';
import 'package:core_content/testing.dart';
import 'package:core_domain/core_domain.dart';
import 'package:experience/experience.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:viet_su/app_router.dart';
import 'package:viet_su/state/narration_controller.dart';
import 'package:viet_su/state/providers.dart';
import 'package:viet_su/state/reminder_service.dart';
import 'package:viet_su/state/today_store.dart';
import 'package:viet_su/state/unlock_store.dart';
import 'package:viet_su/state/visit_store.dart';
import 'package:viet_su/widgets/unlock/mystery_art.dart';
import 'package:viet_su/widgets/unlock/unlock_quiz_sheet.dart';

import 'memory_stores.dart';

late List<Era> _eras;
late Set<String> _hidden;
// A hidden person and event with pages to open.
late String _personKey, _personRoute, _eventKey, _eventRoute;
late Era _hubEra;

Future<ProviderContainer> _pump(
  WidgetTester tester,
  String location,
  ExperienceTier tier, {
  UnlockData data = const UnlockData(migrated: true, installSeed: 5),
  DateTime? now,
}) async {
  final container = ProviderContainer(overrides: <Override>[
    tierProvider.overrideWithValue(tier),
    contentRepositoryProvider.overrideWithValue(
        ContentRepository(DiskContentSource(Directory('../../content')))),
    visitStoreProvider.overrideWithValue(MemoryVisitStore()),
    narrationStoreProvider.overrideWithValue(MemoryNarrationStore()),
    todayStoreProvider.overrideWithValue(MemoryTodayStore()),
    reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
    unlockStoreProvider.overrideWithValue(MemoryUnlockStore(data)),
    if (now != null) unlockClockProvider.overrideWithValue(() => now),
  ]);
  addTearDown(container.dispose);
  final router = container.read(routerProvider);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: ExperienceScope(
      tier: tier,
      child: MaterialApp.router(routerConfig: router, theme: VSTheme.build()),
    ),
  ));
  await tester.pump();
  router.go(location);
  await tester.pump();
  if (tier == ExperienceTier.reduced) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(seconds: 1));
  }
  return container;
}

void main() {
  setUpAll(() async {
    _eras = await ContentRepository(DiskContentSource(Directory('../../content')))
        .loadAllEras();
    _hidden = hiddenArtKeys(_eras);
    for (final era in _eras.where(hasHiddenArt)) {
      for (final c in era.characters) {
        final k = VisitKey.person(c.id);
        if (_hidden.contains(k) && c.fullBody != null) {
          _personKey = k;
          _personRoute = '/era/${era.slug}/figure/${c.id}';
          _hubEra = era;
          break;
        }
      }
      for (final e in era.events) {
        final k = VisitKey.event(e.id);
        if (_hidden.contains(k)) {
          _eventKey = k;
          _eventRoute = '/era/${era.slug}/event/${e.id}';
          break;
        }
      }
      if (_personKey.isNotEmpty && _eventKey.isNotEmpty) break;
    }
  });

  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1.0;
  });
  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  group('the gate at its three places', () {
    testWidgets('era hub roster: hidden portraits show a mystery, open ones do not',
        (tester) async {
      await _pump(tester, '/era/${_hubEra.slug}', ExperienceTier.reduced);
      expect(find.byKey(const ValueKey<String>('mystery-question')),
          findsWidgets);
      expect(find.byKey(const ValueKey<String>('era-unlock-header')),
          findsOneWidget);
      expect(
          find.textContaining('chân dung'), findsWidgets);
    });

    testWidgets('era hub roster with everything open has no mystery',
        (tester) async {
      await _pump(tester, '/era/${_hubEra.slug}', ExperienceTier.reduced,
          data: UnlockData(
              migrated: true, installSeed: 5, unlocked: _hidden));
      expect(find.byKey(const ValueKey<String>('mystery-question')),
          findsNothing);
      expect(find.byType(MysteryArt), findsNothing);
    });

    testWidgets('character page: mystery, prompt; open: the real image, no frame',
        (tester) async {
      await _pump(tester, _personRoute, ExperienceTier.reduced);
      expect(find.byType(MysteryArt), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('unlock-prompt')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('art-gate-tap')), findsOneWidget);

      await _pump(tester, _personRoute, ExperienceTier.reduced,
          data: UnlockData(
              migrated: true, installSeed: 5, unlocked: {_personKey}));
      expect(find.byType(MysteryArt), findsNothing);
      expect(find.byKey(const ValueKey<String>('unlock-prompt')), findsNothing);
    });

    testWidgets('event page: hero is a mystery with a prompt; open shows none',
        (tester) async {
      await _pump(tester, _eventRoute, ExperienceTier.reduced);
      // (A leader in the figure strip may be hidden too, so count the hero by
      // its own tap target.)
      expect(find.byType(MysteryArt), findsWidgets);
      expect(find.byKey(const ValueKey<String>('unlock-prompt')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('art-gate-tap')), findsOneWidget);

      await _pump(tester, _eventRoute, ExperienceTier.reduced,
          data: UnlockData(
              migrated: true, installSeed: 5, unlocked: {_eventKey}));
      expect(find.byKey(const ValueKey<String>('art-gate-tap')), findsNothing);
      expect(find.byKey(const ValueKey<String>('unlock-prompt')), findsNothing);
    });

    testWidgets('a photographed era has no mystery anywhere', (tester) async {
      final era = _eras.firstWhere((e) => !hasHiddenArt(e));
      await _pump(tester, '/era/${era.slug}', ExperienceTier.reduced);
      expect(find.byType(MysteryArt), findsNothing);
      expect(find.byKey(const ValueKey<String>('era-unlock-header')),
          findsNothing);
    });
  });

  group('unlocking from a page', () {
    testWidgets('a wrong answer can be retried until right, then the art opens',
        (tester) async {
      final c = await _pump(tester, _personRoute, ExperienceTier.reduced);
      await tester.tap(find.byKey(const ValueKey<String>('unlock-prompt')));
      await tester.pumpAndSettle();

      final q = (await tester.runAsync(
          () => c.read(unlockQuestionProvider(_personKey).future)))!;
      Finder inSheet(String t) =>
          find.descendant(of: find.byType(BottomSheet), matching: find.text(t));
      final wrong = q.options[(q.correctIndex + 1) % 4].vi;
      final wrong2 = q.options[(q.correctIndex + 2) % 4].vi;
      final right = q.options[q.correctIndex].vi;

      await tester.tap(inSheet(wrong));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('unlock-retry')), findsOneWidget);
      // Nothing is lost: still locked, and the same option does nothing.
      expect(c.read(artHiddenProvider(_personKey)), isTrue);
      await tester.tap(inSheet(wrong));
      await tester.pumpAndSettle();

      await tester.tap(inSheet(wrong2));
      await tester.pumpAndSettle();
      await tester.tap(inSheet(right));
      await tester.pumpAndSettle();
      // The citation shows after the right answer; the art is still hidden
      // until the sheet closes.
      expect(find.byKey(const ValueKey<String>('unlock-continue')),
          findsOneWidget);
      expect(c.read(artHiddenProvider(_personKey)), isTrue);

      await tester.tap(find.byKey(const ValueKey<String>('unlock-continue')));
      await tester.pump();
      await tester.pump();
      expect(c.read(artHiddenProvider(_personKey)), isFalse);
      expect(c.read(unlockProvider).requireValue.quizCount, 1);
      // The reveal plays (reduced: a short crossfade) and then the art stands
      // alone.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.byType(MysteryArt), findsNothing);
      expect(find.byKey(const ValueKey<String>('unlock-prompt')), findsNothing);
    });

    testWidgets('the reveal captions the count and the streak', (tester) async {
      final c = await _pump(tester, _personRoute, ExperienceTier.reduced);
      await c.read(unlockProvider.future);
      await c.read(unlockProvider.notifier).unlockByQuiz(_personKey);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      final cap = tester.widget<Text>(
          find.byKey(const ValueKey<String>('reveal-caption')));
      expect(cap.data, startsWith('+1 · 1/${_hidden.length}'));
      expect(cap.data, contains('Chuỗi 1 ngày'));
      await tester.pumpAndSettle();
    });

    testWidgets('the full reveal plays on the flagship tier and ends clean',
        (tester) async {
      final c = await _pump(tester, _eventRoute, ExperienceTier.flagship);
      await c.read(unlockProvider.future);
      await c.read(unlockProvider.notifier).unlockByQuiz(_eventKey);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      // Mid-reveal: both layers exist.
      expect(find.byKey(const ValueKey<String>('reveal-caption')),
          findsOneWidget);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey<String>('reveal-caption')), findsNothing);
      expect(find.byKey(const ValueKey<String>('unlock-prompt')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tap skips the reveal', (tester) async {
      final c = await _pump(tester, _eventRoute, ExperienceTier.flagship);
      await c.read(unlockProvider.future);
      await c.read(unlockProvider.notifier).unlockByQuiz(_eventKey);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey<String>('reveal-caption')),
          findsOneWidget);
      await tester.tapAt(const Offset(195, 150));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey<String>('reveal-caption')), findsNothing);
    });

    testWidgets('once today\'s unlocks are used the page says so',
        (tester) async {
      final day = DateTime(2026, 10, 24, 10);
      await _pump(tester, _personRoute, ExperienceTier.reduced,
          now: day,
          data: UnlockData(
            migrated: true,
            installSeed: 5,
            quizDay: dayKey(day),
            quizCount: kQuizUnlocksPerDay,
            streak: StreakState(current: 4, best: 4, lastDay: dayKey(day)),
          ));
      expect(find.textContaining('Hết lượt mở khóa hôm nay'), findsOneWidget);
      expect(find.textContaining('Chuỗi 4 ngày'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('art-gate-tap')), findsNothing);
    });
  });

  group('the daily gift', () {
    testWidgets('the Sảnh card opens the gift, then shows the counts',
        (tester) async {
      final c = await _pump(tester, '/sanh', ExperienceTier.reduced,
          now: DateTime(2026, 10, 24, 9));
      expect(find.byKey(const ValueKey<String>('sanh-gift-card')),
          findsOneWidget);
      expect(find.textContaining('Đã mở 0/${_hidden.length}'), findsOneWidget);

      await tester.tap(find.text('Một bức ảnh đang chờ'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('gift-open')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      final d = c.read(unlockProvider).requireValue;
      expect(d.unlocked, hasLength(1));
      expect(d.streak.current, 1);
      expect(find.byKey(const ValueKey<String>('gift-view-page')),
          findsOneWidget);
      expect(
          tester
              .widget<Text>(find.byKey(const ValueKey<String>('gift-streak')))
              .data,
          contains('Chuỗi 1 ngày'));
    });

    testWidgets('the card reads "opened" once the gift has been opened',
        (tester) async {
      final day = DateTime(2026, 10, 24, 9);
      await _pump(tester, '/sanh', ExperienceTier.reduced,
          now: day,
          data: UnlockData(
            migrated: true,
            installSeed: 5,
            giftDate: dayKey(day),
            giftKey: _personKey,
            unlocked: {_personKey},
            streak: StreakState(
                current: 5, best: 5, lastDay: dayKey(day), freezes: 1),
          ));
      expect(find.text('Đã mở hôm nay ✓'), findsOneWidget);
      expect(
          tester
              .widget<Text>(
                  find.byKey(const ValueKey<String>('gift-card-summary')))
              .data,
          'Đã mở 1/${_hidden.length} · 🔥 Chuỗi 5 ngày · 1 lượt giữ chuỗi');
      await tester.tap(find.byKey(const ValueKey<String>('gift-card-expand')));
      await tester.pumpAndSettle();
      expect(find.text('Tiến trình chỉ được lưu trên máy này.'), findsOneWidget);
    });

    testWidgets('the Home chip glows until opened, then shows the streak',
        (tester) async {
      final day = DateTime(2026, 10, 24, 9);
      await _pump(tester, '/', ExperienceTier.reduced, now: day);
      expect(find.text('🎁 Quà hôm nay'), findsOneWidget);

      await _pump(tester, '/', ExperienceTier.reduced,
          now: day,
          data: UnlockData(
            migrated: true,
            installSeed: 5,
            giftDate: dayKey(day),
            giftKey: _personKey,
            unlocked: {_personKey},
            streak: StreakState(current: 3, best: 3, lastDay: dayKey(day)),
          ));
      expect(find.text('🔥 Chuỗi 3 ngày'), findsOneWidget);
    });

    testWidgets('every 5th gift offers the reminder again, only while it is off',
        (tester) async {
      Future<void> claimFifth() async {
        await tester.tap(find.text('Một bức ảnh đang chờ'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey<String>('gift-open')));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        // Close the gift sheet.
        await tester.tapAt(const Offset(195, 40));
        await tester.pumpAndSettle();
      }

      final day = DateTime(2026, 10, 24, 9);
      const fourth = UnlockData(migrated: true, installSeed: 5, giftClaims: 4);
      await _pump(tester, '/sanh', ExperienceTier.reduced,
          now: day, data: fourth);
      await claimFifth();
      expect(find.byKey(const ValueKey<String>('reminder-sheet-time')),
          findsOneWidget);
      await tester.tapAt(const Offset(195, 40));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      // Not the 5th claim: no offer.
      await _pump(tester, '/sanh', ExperienceTier.reduced,
          now: day,
          data: const UnlockData(migrated: true, installSeed: 5, giftClaims: 2));
      await claimFifth();
      expect(find.byKey(const ValueKey<String>('reminder-sheet-time')),
          findsNothing);
    });

    testWidgets('a lost streak is said once, calmly', (tester) async {
      final day = DateTime(2026, 10, 24, 9);
      final c = await _pump(tester, '/sanh', ExperienceTier.reduced,
          now: day,
          data: UnlockData(
            migrated: true,
            installSeed: 5,
            lostStreak: 6,
            giftDate: dayKey(day),
            giftKey: _personKey,
            unlocked: {_personKey},
            streak: StreakState(current: 1, best: 6, lastDay: dayKey(day)),
          ));
      await tester.tap(find.text('Đã mở hôm nay ✓'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('streak-lost-note')),
          findsOneWidget);
      expect(c.read(unlockProvider).requireValue.lostStreak, 0);
    });
  });
}
