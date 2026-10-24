import 'dart:convert';
import 'dart:io';

import 'package:core_content/core_content.dart';
import 'package:core_content/testing.dart';
import 'package:core_domain/core_domain.dart';
import 'package:experience/experience.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:viet_su/app_router.dart';
import 'package:viet_su/state/narration_controller.dart';
import 'package:viet_su/state/providers.dart';
import 'package:viet_su/state/reminder_service.dart';
import 'package:viet_su/state/tip_store.dart';
import 'package:viet_su/state/today_provider.dart';
import 'package:viet_su/state/today_store.dart';
import 'package:viet_su/state/visit_store.dart';
import 'package:viet_su/telemetry/telemetry.dart';

import 'memory_stores.dart';

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
  @override
  Future<void> setCommonProperty(String key, Object value) async {}
}

PeopleRegistry _people() => PeopleRegistry.fromJson(
    jsonDecode(File('../../content/people.json').readAsStringSync())
        as Map<String, dynamic>);

/// A real event (so the router can find its era), with an anniversary that is
/// today.
HistoryEvent _realEventOnAnniversary(String id, DateTime today) {
  final people = _people();
  final registry = EventRegistry.fromJson(
      jsonDecode(File('../../content/events.json').readAsStringSync())
          as Map<String, dynamic>);
  for (final f in Directory('../../content/eras').listSync().whereType<File>()) {
    if (!f.path.endsWith('.json')) continue;
    final era = Era.fromJson(
        jsonDecode(f.readAsStringSync()) as Map<String, dynamic>, people, registry);
    for (final e in era.events) {
      if (e.id != id) continue;
      return HistoryEvent(
        id: e.id,
        order: e.order,
        kind: e.kind,
        year: e.year,
        anniversary: Anniversary(
            month: today.month, day: today.day, calendar: AnniversaryCalendar.solar),
        title: e.title,
        summary: e.summary,
        citation: e.citation,
        figureIds: e.figureIds,
      );
    }
  }
  throw StateError('no event $id');
}

HistoryEvent _plain(String id, {int year = 1900, Anniversary? on}) => HistoryEvent(
      id: id,
      order: 0,
      kind: EventKind.historical,
      year: YearRef(display: LocalizedText(vi: '$year'), value: year),
      anniversary: on,
      title: LocalizedText(vi: 'Sự kiện $id', en: 'Event $id'),
      summary: LocalizedText(vi: 'Tóm tắt $id', en: 'Summary $id'),
      citation: const Citation(work: 'test'),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('todayKicker', () {
    const anniversary = TodayItem(
        kind: TodayKind.event,
        id: 'x',
        reason: TodayReason.anniversary,
        eventYear: 1975,
        yearsAgo: 51);

    test('an anniversary names the year, in both languages', () {
      expect(todayKicker(anniversary, Lang.vi), 'Ngày này năm 1975');
      expect(todayKicker(anniversary, Lang.en), 'On this day in 1975');
    });

    test('a round anniversary says how many years', () {
      const round = TodayItem(
          kind: TodayKind.event,
          id: 'x',
          reason: TodayReason.anniversary,
          eventYear: 1975,
          yearsAgo: 50);
      expect(todayKicker(round, Lang.vi), 'Ngày này năm 1975 · 50 năm');
      expect(todayKicker(round, Lang.en), 'On this day in 1975 · 50 years ago');
    });

    test('an anniversary with no exact year, and the rotation kinds', () {
      const legend = TodayItem(
          kind: TodayKind.event, id: 'x', reason: TodayReason.anniversary);
      expect(todayKicker(legend, Lang.vi), 'Ngày này năm xưa');
      expect(todayKicker(legend, Lang.en), 'On this day');
      const person =
          TodayItem(kind: TodayKind.person, id: 'p', reason: TodayReason.rotation);
      const event =
          TodayItem(kind: TodayKind.event, id: 'e', reason: TodayReason.rotation);
      expect(todayKicker(person, Lang.vi), 'Nhân vật hôm nay');
      expect(todayKicker(event, Lang.en), 'Event of the day');
    });
  });

  group('TodayContext', () {
    test('lists each event once, and words a pick from the content', () {
      const people = PeopleRegistry(<String, Character>{
        'p': Character(
            id: 'p',
            name: LocalizedText(vi: 'Người P', en: 'P'),
            epithet: LocalizedText(vi: 'Anh hùng')),
      });
      final ctx = TodayContext(
          events: [_plain('a'), _plain('a'), _plain('b')], people: people);
      expect(ctx.events.map((e) => e.id), ['a', 'b']);
      expect(ctx.viewOf(const TodayItem(kind: TodayKind.event, id: 'b', reason: TodayReason.rotation))!.title.vi,
          'Sự kiện b');
      final person = ctx.viewOf(const TodayItem(kind: TodayKind.person, id: 'p', reason: TodayReason.rotation))!;
      expect((person.title.vi, person.summary!.vi), ('Người P', 'Anh hùng'));
      expect(ctx.viewOf(const TodayItem(kind: TodayKind.person, id: 'gone', reason: TodayReason.rotation)), isNull);
    });
  });

  group('buildReminderEntries', () {
    final ctx = TodayContext(
      events: [for (var i = 0; i < 40; i++) _plain('e$i', year: 1000 + i)],
      people: PeopleRegistry.empty,
    );

    test('14 days, one per calendar day, at the chosen time', () {
      final entries = buildReminderEntries(
          context: ctx, now: DateTime(2026, 10, 23, 7, 0), minutes: 8 * 60, lang: Lang.vi);
      expect(entries, hasLength(14));
      expect(entries.first.at, DateTime(2026, 10, 23, 8, 0));
      expect(entries.last.at, DateTime(2026, 11, 5, 8, 0));
      expect(entries.map((e) => e.id).toSet(), hasLength(14));
      expect(entries.first.id, 20261023);
      expect(entries[9].id, 20261101); // across a month end
    });

    test('a time already past today starts tomorrow, still 14 days', () {
      final entries = buildReminderEntries(
          context: ctx, now: DateTime(2026, 10, 23, 9, 0), minutes: 8 * 60, lang: Lang.vi);
      expect(entries, hasLength(14));
      expect(entries.first.at, DateTime(2026, 10, 24, 8, 0));
    });

    test('each entry carries that day\'s pick, worded in the language', () {
      final vi = buildReminderEntries(
          context: ctx, now: DateTime(2026, 10, 23, 7, 0), minutes: 480, lang: Lang.vi);
      final en = buildReminderEntries(
          context: ctx, now: DateTime(2026, 10, 23, 7, 0), minutes: 480, lang: Lang.en);
      final pick = ctx.viewFor(DateTime(2026, 10, 23))!;
      expect(vi.first.body, '${pick.title.vi} · Quà hôm nay đang chờ bạn');
      expect(vi.first.title, todayKicker(pick.item, Lang.vi));
      expect(en.first.body, "${pick.title.en} · Today's gift is waiting");
      expect(en.first.title, todayKicker(pick.item, Lang.en));
    });

    test('nothing to show means nothing scheduled', () {
      final empty = TodayContext(events: const [], people: PeopleRegistry.empty);
      expect(
          buildReminderEntries(
              context: empty, now: DateTime(2026, 10, 23), minutes: 480, lang: Lang.vi),
          isEmpty);
    });
  });

  group('FileTodayStore', () {
    test('round-trips, survives a corrupt file, and clamps a bad time', () async {
      final dir = Directory.systemTemp.createTempSync('today_store_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async =>
              call.method == 'getApplicationSupportDirectory' ? dir.path : null);
      addTearDown(() => TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));

      await FileTodayStore().save(const TodayPrefs(
          openedDate: '2026-10-23', reminderOn: true, reminderMinutes: 450, asked: true));
      final back = await FileTodayStore().load();
      expect((back.openedDate, back.reminderOn, back.reminderMinutes, back.asked),
          ('2026-10-23', true, 450, true));
      expect(back.openedOn(DateTime(2026, 10, 23)), isTrue);
      expect(back.openedOn(DateTime(2026, 10, 24)), isFalse);

      File('${dir.path}/today.json')
          .writeAsStringSync('{"reminderOn":true,"reminderMinutes":99999}');
      final clamped = await FileTodayStore().load();
      expect(clamped.reminderOn, isTrue);
      expect(clamped.reminderMinutes, kDefaultReminderMinutes);

      File('${dir.path}/today.json').writeAsStringSync('nope');
      final bad = await FileTodayStore().load();
      expect((bad.reminderOn, bad.asked), (false, false));
    });
  });

  group('TodayPrefsNotifier', () {
    test('markOpened, markAsked and setReminder persist', () async {
      final store = MemoryTodayStore();
      final c = ProviderContainer(
          overrides: [todayStoreProvider.overrideWithValue(store)]);
      addTearDown(c.dispose);
      final n = c.read(todayPrefsProvider.notifier);
      await c.read(todayPrefsProvider.future);

      await n.markOpened(DateTime(2026, 10, 23));
      expect(store.prefs.openedOn(DateTime(2026, 10, 23)), isTrue);

      await n.setReminder(on: true, minutes: 7 * 60 + 30);
      expect((store.prefs.reminderOn, store.prefs.reminderMinutes, store.prefs.asked),
          (true, 450, true));
      // Turning it off keeps the chosen time.
      await n.setReminder(on: false);
      expect((store.prefs.reminderOn, store.prefs.reminderMinutes), (false, 450));
    });
  });

  group('reminderSyncProvider', () {
    ProviderContainer make(
      FakeReminderScheduler scheduler, {
      TodayPrefs prefs = const TodayPrefs(),
    }) {
      final c = ProviderContainer(overrides: [
        todayStoreProvider.overrideWithValue(MemoryTodayStore(prefs)),
        reminderSchedulerProvider.overrideWithValue(scheduler),
        todayContextProvider.overrideWith((ref) async => TodayContext(
            events: [for (var i = 0; i < 40; i++) _plain('e$i', year: 1000 + i)],
            people: PeopleRegistry.empty)),
        contentRepositoryProvider.overrideWithValue(
            ContentRepository(DiskContentSource(Directory('../../content')))),
        visitStoreProvider.overrideWithValue(MemoryVisitStore()),
        narrationStoreProvider.overrideWithValue(MemoryNarrationStore()),
        telemetryProvider.overrideWithValue(_Events()),
      ]);
      addTearDown(c.dispose);
      // Keep the sync provider alive, as the app does.
      c.listen(reminderSyncProvider, (_, __) {});
      return c;
    }

    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('a reader who was never asked has nothing scheduled or cancelled', () async {
      final s = FakeReminderScheduler();
      make(s);
      await settle();
      expect(s.inits, 0);
      expect(s.cancels, 0);
      expect(s.history, isEmpty);
    });

    test('a reader who said yes gets the next 14 days scheduled', () async {
      final s = FakeReminderScheduler();
      make(s, prefs: const TodayPrefs(reminderOn: true, asked: true));
      await settle();
      expect(s.inits, 1);
      expect(s.scheduled, hasLength(14));
      expect(s.scheduled.first.at.hour, 8);
    });

    test('turning it off cancels what is pending', () async {
      final s = FakeReminderScheduler();
      final c = make(s, prefs: const TodayPrefs(reminderOn: true, asked: true));
      await settle();
      expect(s.scheduled, isNotEmpty);
      await c.read(todayPrefsProvider.notifier).setReminder(on: false);
      await settle();
      expect(s.cancels, greaterThan(0));
      expect(s.scheduled, isEmpty);
    });

    test('changing the time re-schedules at the new time', () async {
      final s = FakeReminderScheduler();
      final c = make(s, prefs: const TodayPrefs(reminderOn: true, asked: true));
      await settle();
      await c.read(todayPrefsProvider.notifier).setReminder(on: true, minutes: 20 * 60 + 15);
      await settle();
      expect(s.scheduled.first.at.hour, 20);
      expect(s.scheduled.first.at.minute, 15);
    });

    test('changing the language re-schedules in that language', () async {
      final s = FakeReminderScheduler();
      final c = make(s, prefs: const TodayPrefs(reminderOn: true, asked: true));
      await settle();
      expect(s.scheduled.first.title, anyOf(startsWith('Nhân vật'), startsWith('Sự kiện')));
      c.read(langProvider.notifier).state = Lang.en;
      await settle();
      expect(s.scheduled.first.title, anyOf(startsWith('Figure'), startsWith('Event')));
    });

    test('tapping a reminder opens today\'s pick, and is logged', () async {
      final s = FakeReminderScheduler();
      final c = make(s, prefs: const TodayPrefs(reminderOn: true, asked: true));
      await settle();
      s.onOpen!();
      await settle();
      final prefs = await c.read(todayPrefsProvider.future);
      expect(prefs.openedOn(DateTime.now()), isTrue);
      expect(c.read(telemetryProvider), isA<_Events>());
      expect(
          (c.read(telemetryProvider) as _Events)
              .events
              .where((e) => e.$1 == 'today_open' && e.$2['source'] == 'notification'),
          hasLength(1));
    });
  });

  group('Sảnh · Hôm nay', () {
    late HistoryEvent event;
    late _Events telemetry;
    late MemoryTodayStore todayStore;
    late FakeReminderScheduler scheduler;

    Future<GoRouter> pump(
      WidgetTester tester, {
      TodayPrefs prefs = const TodayPrefs(),
      FakeReminderScheduler? sched,
      bool vietnamese = true,
    }) async {
      event = _realEventOnAnniversary('chien-dich-ho-chi-minh', DateTime.now());
      telemetry = _Events();
      todayStore = MemoryTodayStore(prefs);
      scheduler = sched ?? FakeReminderScheduler();
      final container = ProviderContainer(overrides: [
        tierProvider.overrideWithValue(ExperienceTier.reduced),
        contentRepositoryProvider.overrideWithValue(
            ContentRepository(DiskContentSource(Directory('../../content')))),
        tipStoreProvider.overrideWithValue(null),
        telemetryProvider.overrideWithValue(telemetry),
        visitStoreProvider.overrideWithValue(MemoryVisitStore()),
        narrationStoreProvider.overrideWithValue(MemoryNarrationStore()),
        todayStoreProvider.overrideWithValue(todayStore),
        reminderSchedulerProvider.overrideWithValue(scheduler),
        todayContextProvider.overrideWith((ref) async =>
            TodayContext(events: [event], people: PeopleRegistry.empty)),
      ]);
      addTearDown(container.dispose);
      if (!vietnamese) container.read(langProvider.notifier).state = Lang.en;
      final router = container.read(routerProvider);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: ExperienceScope(
          tier: ExperienceTier.reduced,
          child: MaterialApp.router(
            routerConfig: router,
            theme: VSTheme.build(),
          ),
        ),
      ));
      await tester.pump();
      router.go('/sanh');
      await tester.pump();
      await tester.pumpAndSettle();
      return router;
    }

    String path(GoRouter r) =>
        r.routerDelegate.currentConfiguration.last.matchedLocation;

    testWidgets('the card shows today\'s anniversary, with its kicker and title',
        (tester) async {
      await pump(tester);
      expect(find.byKey(const ValueKey<String>('sanh-today-card')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('today-kicker'))).data,
          startsWith('NGÀY NÀY NĂM '));
      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('today-title'))).data,
          event.title.vi);
      expect(find.byKey(const ValueKey<String>('today-unopened')), findsOneWidget);
    });

    testWidgets('in English the card is in English', (tester) async {
      await pump(tester, vietnamese: false);
      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('today-kicker'))).data,
          startsWith('ON THIS DAY IN '));
      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('today-title'))).data,
          event.title.en ?? event.title.vi);
    });

    testWidgets('tapping it opens the event\'s own page, marks it read and logs it',
        (tester) async {
      final router = await pump(tester, prefs: const TodayPrefs(asked: true));
      await tester.tap(find.byKey(const ValueKey<String>('sanh-today-card')));
      await tester.pumpAndSettle();
      expect(path(router), endsWith('/event/${event.id}'));
      expect(todayStore.prefs.openedOn(DateTime.now()), isTrue);
      expect(telemetry.events.where((e) => e.$1 == 'today_open' && e.$2['source'] == 'sanh'),
          hasLength(1));

      router.pop();
      await tester.pumpAndSettle();
      expect(path(router), '/sanh');
      expect(find.byKey(const ValueKey<String>('today-opened')), findsOneWidget);
    });

    testWidgets('back from the first read, the reminder is offered once: "not now"',
        (tester) async {
      final router = await pump(tester);
      await tester.tap(find.byKey(const ValueKey<String>('sanh-today-card')));
      await tester.pumpAndSettle();
      router.pop();
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('reminder-sheet-yes')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('reminder-sheet-later')));
      await tester.pumpAndSettle();
      expect(todayStore.prefs.asked, isTrue);
      expect(todayStore.prefs.reminderOn, isFalse);
      expect(scheduler.permissionRequests, 0);

      // Never asked again.
      await tester.tap(find.byKey(const ValueKey<String>('sanh-today-card')));
      await tester.pumpAndSettle();
      router.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('reminder-sheet-yes')), findsNothing);
    });

    testWidgets('"remind me" asks the system, then turns the reminder on',
        (tester) async {
      final router = await pump(tester);
      await tester.tap(find.byKey(const ValueKey<String>('sanh-today-card')));
      await tester.pumpAndSettle();
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('reminder-sheet-yes')));
      await tester.pumpAndSettle();

      expect(scheduler.permissionRequests, 1);
      expect(todayStore.prefs.reminderOn, isTrue);
      expect(todayStore.prefs.reminderMinutes, kDefaultReminderMinutes);
      expect(telemetry.events.where((e) => e.$1 == 'notif_optin' && e.$2['granted'] == 1),
          hasLength(1));
    });

    testWidgets('if the system says no, the reminder stays off and says why, calmly',
        (tester) async {
      final router = await pump(tester, sched: FakeReminderScheduler(grant: false));
      await tester.tap(find.byKey(const ValueKey<String>('sanh-today-card')));
      await tester.pumpAndSettle();
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('reminder-sheet-yes')));
      await tester.pumpAndSettle();

      expect(todayStore.prefs.reminderOn, isFalse);
      expect(todayStore.prefs.asked, isTrue);
      expect(find.textContaining('Thông báo của Long Ký đang tắt'), findsOneWidget);
      expect(telemetry.events.where((e) => e.$1 == 'notif_optin' && e.$2['granted'] == 0),
          hasLength(1));
    });

    testWidgets('the Sảnh switch turns it on and off; off cancels', (tester) async {
      await pump(tester, prefs: const TodayPrefs(asked: true));
      final row = find.byKey(const ValueKey<String>('sanh-reminder-row'));
      // The directory is a lazy list: scroll until the row is built.
      await tester.scrollUntilVisible(row, 300,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      final sw = find.descendant(of: row, matching: find.byType(Switch));
      expect(tester.widget<Switch>(sw).value, isFalse);

      await tester.tap(sw);
      await tester.pumpAndSettle();
      expect(todayStore.prefs.reminderOn, isTrue);
      expect(find.textContaining('Mỗi ngày lúc 08:00'), findsOneWidget);
      expect(telemetry.events.where((e) => e.$1 == 'notif_toggle' && e.$2['on'] == 1),
          hasLength(1));

      await tester.tap(sw);
      await tester.pumpAndSettle();
      expect(todayStore.prefs.reminderOn, isFalse);
      expect(telemetry.events.where((e) => e.$1 == 'notif_toggle' && e.$2['on'] == 0),
          hasLength(1));
    });

    testWidgets('on web and desktop there is no reminder row', (tester) async {
      // The no-op scheduler is what those platforms get.
      final container = ProviderContainer(overrides: [
        tierProvider.overrideWithValue(ExperienceTier.reduced),
        contentRepositoryProvider.overrideWithValue(
            ContentRepository(DiskContentSource(Directory('../../content')))),
        tipStoreProvider.overrideWithValue(null),
        telemetryProvider.overrideWithValue(_Events()),
        visitStoreProvider.overrideWithValue(MemoryVisitStore()),
        narrationStoreProvider.overrideWithValue(MemoryNarrationStore()),
        todayStoreProvider.overrideWithValue(MemoryTodayStore()),
        reminderSchedulerProvider.overrideWithValue(const NoopReminderScheduler()),
        todayContextProvider.overrideWith((ref) async =>
            TodayContext(events: [_plain('a')], people: PeopleRegistry.empty)),
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
      await tester.pump();
      router.go('/sanh');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('sanh-reminder-row')), findsNothing);
      // The card itself still works without notifications.
      expect(find.byKey(const ValueKey<String>('sanh-today-card')), findsOneWidget);
    });
  });

  group('/hom-nay', () {
    testWidgets('lands on a person\'s own page when the pick is a person',
        (tester) async {
      final people = _people();
      final container = ProviderContainer(overrides: [
        tierProvider.overrideWithValue(ExperienceTier.reduced),
        contentRepositoryProvider.overrideWithValue(
            ContentRepository(DiskContentSource(Directory('../../content')))),
        tipStoreProvider.overrideWithValue(null),
        telemetryProvider.overrideWithValue(_Events()),
        visitStoreProvider.overrideWithValue(MemoryVisitStore()),
        narrationStoreProvider.overrideWithValue(MemoryNarrationStore()),
        todayStoreProvider.overrideWithValue(MemoryTodayStore()),
        reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
        // Only one person in the pool, so the pick is that person.
        todayContextProvider.overrideWith((ref) async => TodayContext(
            events: const [],
            people: PeopleRegistry(<String, Character>{'le-loi': people['le-loi']!}))),
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
      await tester.pump();
      router.go('/hom-nay');
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.last.matchedLocation,
          endsWith('/figure/le-loi'));
    });

    testWidgets('with nothing to show it lands calmly on the Sảnh', (tester) async {
      final container = ProviderContainer(overrides: [
        tierProvider.overrideWithValue(ExperienceTier.reduced),
        contentRepositoryProvider.overrideWithValue(
            ContentRepository(DiskContentSource(Directory('../../content')))),
        tipStoreProvider.overrideWithValue(null),
        telemetryProvider.overrideWithValue(_Events()),
        visitStoreProvider.overrideWithValue(MemoryVisitStore()),
        narrationStoreProvider.overrideWithValue(MemoryNarrationStore()),
        todayStoreProvider.overrideWithValue(MemoryTodayStore()),
        reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
        todayContextProvider.overrideWith((ref) async =>
            TodayContext(events: const [], people: PeopleRegistry.empty)),
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
      await tester.pump();
      router.go('/hom-nay');
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.last.matchedLocation,
          '/sanh');
    });
  });
}
