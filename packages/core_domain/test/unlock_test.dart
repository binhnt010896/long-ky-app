import 'dart:convert';
import 'dart:io';

import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

List<Era> _loadAllEras() {
  final people = PeopleRegistry.fromJson(
      jsonDecode(File('../../content/people.json').readAsStringSync())
          as Map<String, dynamic>);
  final events = EventRegistry.fromJson(
      jsonDecode(File('../../content/events.json').readAsStringSync())
          as Map<String, dynamic>);
  final files = Directory('../../content/eras')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final eras = [
    for (final f in files)
      Era.fromJson(
          jsonDecode(f.readAsStringSync()) as Map<String, dynamic>, people, events),
  ]..sort((a, b) => a.order.compareTo(b.order));
  return eras;
}

void main() {
  late List<Era> eras;
  late List<Era> inScope;
  late Set<String> hidden;

  setUpAll(() {
    eras = _loadAllEras();
    inScope = [for (final e in eras) if (hasHiddenArt(e)) e];
    hidden = hiddenArtKeys(eras);
  });

  group('hiddenArtKeys', () {
    test('covers the eras before the photographs and no later one', () {
      expect(inScope.length, 26);
      expect(inScope.last.slug, 'tu-duc');
      expect(eras.where((e) => !hasHiddenArt(e)).first.slug, 'can-vuong');
    });

    test('never hides an era lead, and hides about half of the rest', () {
      for (final era in inScope) {
        if (era.characters.isNotEmpty) {
          expect(hidden, isNot(contains(VisitKey.person(era.characters.first.id))),
              reason: '${era.slug} lead person');
        }
        if (era.events.isNotEmpty) {
          expect(hidden, isNot(contains(VisitKey.event(era.events.first.id))),
              reason: '${era.slug} lead event');
        }
        final ev = era.events.where((e) => hidden.contains(VisitKey.event(e.id)));
        expect(ev.length, era.events.length ~/ 2, reason: '${era.slug} events');
        final pe =
            era.characters.where((c) => hidden.contains(VisitKey.person(c.id)));
        expect(pe.length, lessThanOrEqualTo(era.characters.length ~/ 2),
            reason: '${era.slug} people');
      }
    });

    test('hides nothing outside the scope', () {
      for (final era in eras.where((e) => !hasHiddenArt(e))) {
        for (final e in era.events) {
          expect(hidden, isNot(contains(VisitKey.event(e.id))));
        }
      }
    });

    test('is deterministic, and a person on two rosters is decided once', () {
      expect(hiddenArtKeys(eras), hidden);
      expect(hiddenArtKeys(eras.reversed), isNotNull);
      expect(hidden.length, inInclusiveRange(100, 130));
    });
  });

  group('questionFor', () {
    test('asks every in-scope person and event a fair question, repeatably', () {
      final gen = QuizGenerator(eras);
      final keys = <String>{
        for (final era in inScope) ...[
          for (final c in era.characters) VisitKey.person(c.id),
          for (final e in era.events) VisitKey.event(e.id),
        ],
      };
      expect(keys.length, greaterThan(250));
      for (final key in keys) {
        final q = gen.questionFor(key);
        expect(q, isNotNull, reason: key);
        expect(q!.options, hasLength(4), reason: key);
        expect(q.correctIndex, inInclusiveRange(0, 3), reason: key);
        expect({for (final o in q.options) o.vi}.length, 4,
            reason: '$key has duplicate options');
        expect(q.source.eventId, isNotEmpty, reason: key);
        final again = gen.questionFor(key)!;
        expect(again.prompt.vi, q.prompt.vi, reason: key);
        expect(again.options.map((o) => o.vi), q.options.map((o) => o.vi),
            reason: key);
      }
    });

    test('is null for an unknown or non-page key', () {
      final gen = QuizGenerator(eras);
      expect(gen.questionFor(VisitKey.era('tu-duc')), isNull);
      expect(gen.questionFor(VisitKey.person('no-such-person')), isNull);
      expect(gen.questionFor(VisitKey.event('no-such-event')), isNull);
    });
  });

  group('Streak.advance', () {
    StreakAdvance go(StreakState s, int y, int m, int d) =>
        Streak.advance(s, DateTime(y, m, d, 23, 59));

    test('starts at 1, and counts a day only once', () {
      final a = go(const StreakState(), 2026, 10, 24);
      expect(a.outcome, StreakOutcome.started);
      expect(a.state.current, 1);
      final b = go(a.state, 2026, 10, 24);
      expect(b.outcome, StreakOutcome.unchanged);
      expect(b.state, a.state);
    });

    test('continues across a month end and a year end', () {
      var s = go(const StreakState(), 2026, 1, 30).state;
      s = go(s, 2026, 1, 31).state;
      s = go(s, 2026, 2, 1).state;
      expect(s.current, 3);
      var y = go(const StreakState(), 2026, 12, 31).state;
      y = go(y, 2027, 1, 1).state;
      expect(y.current, 2);
    });

    test('is not broken by a daylight-saving day', () {
      final a = go(const StreakState(), 2026, 3, 28).state;
      expect(go(a, 2026, 3, 29).state.current, 2);
      expect(go(a, 2026, 3, 30).outcome, StreakOutcome.reset);
    });

    test('a missed day resets, keeping the best', () {
      const s = StreakState(current: 5, best: 5, lastDay: '2026-10-20');
      final r = go(s, 2026, 10, 22);
      expect(r.outcome, StreakOutcome.reset);
      expect(r.lost, 5);
      expect(r.state.current, 1);
      expect(r.state.best, 5);
    });

    test('a freeze covers one missed day, but not two', () {
      const s =
          StreakState(current: 5, best: 5, lastDay: '2026-10-20', freezes: 1);
      final one = go(s, 2026, 10, 22);
      expect(one.outcome, StreakOutcome.usedFreeze);
      expect(one.state.current, 6);
      expect(one.state.freezes, 0);
      final two = go(s, 2026, 10, 23);
      expect(two.outcome, StreakOutcome.reset);
      expect(two.state.freezes, 1);
    });

    test('earns a freeze every 7 days, holding at most 2, with milestones', () {
      var s = const StreakState(current: 6, best: 6, lastDay: '2026-10-06');
      var r = go(s, 2026, 10, 7);
      expect(r.state.current, 7);
      expect(r.state.freezes, 1);
      expect(r.milestone, 7);
      s = const StreakState(
          current: 13, best: 13, lastDay: '2026-10-06', freezes: 2);
      r = go(s, 2026, 10, 7);
      expect(r.state.current, 14);
      expect(r.state.freezes, 2);
      expect(r.milestone, isNull);
      r = go(
          const StreakState(current: 29, best: 29, lastDay: '2026-10-06'),
          2026,
          10,
          7);
      expect(r.milestone, 30);
    });

    test('a clock set back never raises the streak', () {
      const s = StreakState(current: 4, best: 4, lastDay: '2026-10-24');
      final r = go(s, 2026, 10, 20);
      expect(r.outcome, StreakOutcome.unchanged);
      expect(r.state, s);
    });
  });

  group('dailyGiftPick', () {
    final remaining = ['person:a', 'person:b', 'event:c', 'event:d', 'event:e'];

    test('is stable within a day, whatever the order', () {
      final day = DateTime(2026, 10, 24);
      final a = dailyGiftPick(remaining, day, 7);
      expect(a, dailyGiftPick(remaining.reversed, day, 7));
      expect(remaining, contains(a));
    });

    test('varies by day and install, and is null when nothing is left', () {
      final picks = {
        for (var d = 1; d <= 28; d++)
          dailyGiftPick(remaining, DateTime(2026, 10, d), 7),
      };
      expect(picks.length, greaterThan(1));
      expect(dailyGiftPick(const <String>[], DateTime(2026, 10, 24), 7), isNull);
    });
  });
}
