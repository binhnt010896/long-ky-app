import 'dart:io';

import 'package:core_content/core_content.dart';
import 'package:core_content/testing.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_su/state/providers.dart';
import 'package:viet_su/state/unlock_store.dart';
import 'package:viet_su/state/visit_store.dart';
import 'package:viet_su/state/narration_controller.dart';
import 'package:viet_su/telemetry/telemetry.dart';

import 'memory_stores.dart';

class _RecordingTelemetry extends NoopTelemetry {
  _RecordingTelemetry();
  final List<(String, Map<String, Object>)> events = [];

  @override
  Future<void> event(String name, [Map<String, Object> params = const {}]) async {
    events.add((name, params));
  }

  Iterable<Map<String, Object>> named(String n) =>
      [for (final e in events) if (e.$1 == n) e.$2];
}

void main() {
  late List<Era> eras;

  setUpAll(() async {
    eras = await ContentRepository(DiskContentSource(Directory('../../content')))
        .loadAllEras();
  });

  ({
    ProviderContainer c,
    MemoryUnlockStore store,
    _RecordingTelemetry tel,
    DateTime Function() now,
    void Function(DateTime) setNow,
  }) make({
    UnlockData? data,
    VisitData? visits,
    Set<String> heard = const <String>{},
  }) {
    var now = DateTime(2026, 10, 24, 9);
    final store = MemoryUnlockStore(data ?? const UnlockData(migrated: true, installSeed: 5));
    final tel = _RecordingTelemetry();
    final c = ProviderContainer(overrides: [
      erasProvider.overrideWith((ref) async => eras),
      unlockStoreProvider.overrideWithValue(store),
      unlockClockProvider.overrideWithValue(() => now),
      visitStoreProvider.overrideWithValue(
          MemoryVisitStore(visits ?? const VisitData(backfilled: true))),
      narrationStoreProvider.overrideWithValue(MemoryNarrationStore(heard)),
      telemetryProvider.overrideWithValue(tel),
    ]);
    addTearDown(c.dispose);
    return (c: c, store: store, tel: tel, now: () => now, setNow: (d) => now = d);
  }

  Future<UnlockNotifier> ready(ProviderContainer c) async {
    await c.read(erasProvider.future);
    await c.read(unlockProvider.future);
    return c.read(unlockProvider.notifier);
  }

  group('first run', () {
    test('pages already opened are unlocked, once, and eras are not', () async {
      final person = VisitKey.person(eras.first.characters.first.id);
      final event = VisitKey.event(eras[2].events.first.id);
      final t = make(
        data: const UnlockData(),
        visits: VisitData(
            visited: {person, VisitKey.era('nha-trieu')}, backfilled: true),
        heard: {'events/${eras[3].events.first.id}', 'eras/au-lac'},
      );
      await ready(t.c);
      final d = t.c.read(unlockProvider).requireValue;
      expect(d.migrated, isTrue);
      expect(d.installSeed, greaterThan(0));
      expect(d.unlocked, contains(person));
      expect(d.unlocked, contains(VisitKey.event(eras[3].events.first.id)));
      expect(d.unlocked, isNot(contains(VisitKey.era('nha-trieu'))));
      expect(d.unlocked, isNot(contains(VisitKey.era('au-lac'))));
      expect(d.unlocked, isNot(contains(event)));
      expect(t.store.data.migrated, isTrue);
    });

    test('does not run again once marked done', () async {
      final person = VisitKey.person(eras.first.characters.first.id);
      final t = make(
        data: const UnlockData(migrated: true, installSeed: 3),
        visits: VisitData(visited: {person}, backfilled: true),
      );
      await ready(t.c);
      expect(t.c.read(unlockProvider).requireValue.unlocked, isEmpty);
    });
  });

  group('a bad file', () {
    test('falls back field by field to defaults', () {
      final d = UnlockData.fromJson(<String, dynamic>{
        'unlocked': 'nope',
        'giftDate': 7,
        'streak': 'x',
        'quizCount': -4,
        'installSeed': 'a',
        'migrated': 'yes',
      });
      expect(d.unlocked, isEmpty);
      expect(d.giftDate, isNull);
      expect(d.streak, const StreakState());
      expect(d.quizCount, 0);
      expect(d.installSeed, 0);
      expect(d.migrated, isFalse);
    });

    test('round-trips', () {
      const d = UnlockData(
        unlocked: {'person:a'},
        giftDate: '2026-10-24',
        giftKey: 'person:a',
        streak: StreakState(current: 3, best: 5, lastDay: '2026-10-24', freezes: 1),
        quizDay: '2026-10-24',
        quizCount: 2,
        migrated: true,
        installSeed: 9,
        lostStreak: 4,
      );
      final back = UnlockData.fromJson(d.toJson());
      expect(back.unlocked, d.unlocked);
      expect(back.streak, d.streak);
      expect(back.quizCount, 2);
      expect(back.lostStreak, 4);
      expect(back.giftKey, 'person:a');
    });
  });

  group('the daily gift', () {
    test('opens one hidden piece once a day and starts the streak', () async {
      final t = make();
      final n = await ready(t.c);
      final hidden = t.c.read(hiddenArtProvider);
      final r = await n.openGift();
      expect(hidden, contains(r.key));
      expect(r.streak!.outcome, StreakOutcome.started);
      expect(t.c.read(artHiddenProvider(r.key!)), isFalse);
      expect(t.c.read(unlockProvider).requireValue.streak.current, 1);

      final again = await n.openGift();
      expect(again.key, r.key);
      expect(t.c.read(unlockProgressProvider).opened, 1);
      expect(t.tel.named('gift_open'), hasLength(1));
      expect(t.tel.named('unlock').single['source'], 'gift');
    });

    test('a new day brings a new gift and a longer streak; a gap resets it',
        () async {
      final t = make();
      final n = await ready(t.c);
      final a = await n.openGift();
      t.setNow(DateTime(2026, 10, 25, 8));
      final b = await n.openGift();
      expect(b.key, isNot(a.key));
      expect(t.c.read(unlockProvider).requireValue.streak.current, 2);

      t.setNow(DateTime(2026, 10, 29, 8));
      await n.openGift();
      final d = t.c.read(unlockProvider).requireValue;
      expect(d.streak.current, 1);
      expect(d.streak.best, 2);
      expect(d.lostStreak, 2);
      expect(t.tel.named('streak_reset').single['lost'], 2);

      await n.dismissLostStreak();
      expect(t.c.read(unlockProvider).requireValue.lostStreak, 0);
    });

    test('a 7th day opens an extra piece', () async {
      final t = make(
        data: const UnlockData(
          migrated: true,
          installSeed: 5,
          streak: StreakState(current: 6, best: 6, lastDay: '2026-10-23'),
        ),
      );
      final n = await ready(t.c);
      final r = await n.openGift();
      expect(r.streak!.milestone, 7);
      expect(r.bonusKey, isNotNull);
      expect(r.bonusKey, isNot(r.key));
      expect(t.c.read(unlockProgressProvider).opened, 2);
      expect(t.tel.named('streak_milestone').single['days'], 7);
      expect(t.tel.named('unlock').map((e) => e['source']),
          containsAll(['gift', 'milestone']));
    });

    test('with everything open it is a congratulation, and Hôm nay keeps the streak',
        () async {
      final t = make();
      final n = await ready(t.c);
      final hidden = t.c.read(hiddenArtProvider);
      await t.store.save(t.store.data.copyWith(unlocked: hidden));
      t.c.invalidate(unlockProvider);
      final n2 = await ready(t.c);
      expect(n2, isNotNull);
      expect(n, isNotNull);
      final r = await t.c.read(unlockProvider.notifier).openGift();
      expect(r.key, isNull);
      expect(t.c.read(unlockProvider).requireValue.streak.current, 1);

      t.setNow(DateTime(2026, 10, 25));
      final today = await t.c.read(unlockProvider.notifier).countToday();
      expect(today!.streak!.outcome, StreakOutcome.continued);
      expect(await t.c.read(unlockProvider.notifier).countToday(), isNull);
    });

    test('countToday does nothing while art is still hidden', () async {
      final t = make();
      final n = await ready(t.c);
      expect(await n.countToday(), isNull);
      expect(t.c.read(unlockProvider).requireValue.streak.current, 0);
    });
  });

  group('quiz unlocks', () {
    test('three a day, then the cap, then a new day', () async {
      final t = make();
      final n = await ready(t.c);
      final keys = t.c.read(hiddenArtProvider).toList()..sort();
      for (var i = 0; i < kQuizUnlocksPerDay; i++) {
        final r = await n.unlockByQuiz(keys[i], attempts: 2);
        expect(r.key, keys[i]);
        expect(r.capHit, isFalse);
      }
      final capped = await n.unlockByQuiz(keys[3]);
      expect(capped.capHit, isTrue);
      expect(t.c.read(artHiddenProvider(keys[3])), isTrue);
      expect(t.tel.named('unlock_cap_hit'), hasLength(1));
      expect(t.tel.named('unlock').first['attempts'], 2);

      t.setNow(DateTime(2026, 10, 25));
      final next = await n.unlockByQuiz(keys[3]);
      expect(next.key, keys[3]);
      expect(t.c.read(unlockProvider).requireValue.streak.current, 2);
    });

    test('a quiz unlock counts the day for the streak, once', () async {
      final t = make();
      final n = await ready(t.c);
      final keys = t.c.read(hiddenArtProvider).toList()..sort();
      final a = await n.unlockByQuiz(keys[0]);
      expect(a.streak!.outcome, StreakOutcome.started);
      final b = await n.unlockByQuiz(keys[1]);
      expect(b.streak, isNull);
      expect(t.c.read(unlockProvider).requireValue.streak.current, 1);
    });

    test('art outside the game is never hidden', () async {
      final t = make();
      await ready(t.c);
      expect(t.c.read(artHiddenProvider(VisitKey.person('no-such'))), isFalse);
      final photographed =
          eras.firstWhere((e) => !hasHiddenArt(e)).events.first.id;
      expect(t.c.read(artHiddenProvider(VisitKey.event(photographed))), isFalse);
    });
  });

  test('era progress counts the hidden pieces of that era', () async {
    final t = make();
    final n = await ready(t.c);
    final era = eras.firstWhere((e) => hasHiddenArt(e) && e.events.length >= 4);
    final before = t.c.read(eraUnlockProgressProvider(era.slug))!;
    expect(before.opened, 0);
    expect(before.eventsTotal, era.events.length ~/ 2);
    final k = t.c.read(hiddenArtProvider).firstWhere((k) =>
        era.events.any((e) => VisitKey.event(e.id) == k));
    await n.unlockByQuiz(k);
    expect(t.c.read(eraUnlockProgressProvider(era.slug))!.eventsOpened, 1);
    final photographed = eras.firstWhere((e) => !hasHiddenArt(e));
    expect(t.c.read(eraUnlockProgressProvider(photographed.slug)), isNull);
  });
}
