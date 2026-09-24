import 'dart:convert';
import 'dart:io';

import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

PeopleRegistry _loadPeople() => PeopleRegistry.fromJson(
    jsonDecode(File('../../content/people.json').readAsStringSync())
        as Map<String, dynamic>);

List<Era> _loadAllEras(PeopleRegistry people) {
  final dir = Directory('../../content/eras');
  final files = dir.listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final eras = <Era>[
    for (final f in files)
      if (f.path.endsWith('.json'))
        Era.fromJson(
          jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
          people,
        ),
  ];
  eras.sort((a, b) => a.order.compareTo(b.order));
  return eras;
}

int _sourceEventId(Question q) => switch (q) {
      McqQuestion(source: final s) => s.eventId.hashCode,
      OrderQuestion() => 0,
    };

int _parseYearLabel(String label) => label.endsWith(' TCN')
    ? -int.parse(label.substring(0, label.length - 4))
    : int.parse(label);

void main() {
  late List<Era> eras;

  setUpAll(() {
    final people = _loadPeople();
    eras = _loadAllEras(people);
  });

  test('loaded the full real chronicle', () {
    expect(eras.length, greaterThan(35));
    final totalEvents = eras.fold<int>(0, (n, e) => n + e.events.length);
    expect(totalEvents, greaterThan(230));
  });

  group('random mode over the full real chronicle', () {
    test('runs without throwing and returns the requested count', () {
      final gen = QuizGenerator(eras);
      for (var seed = 0; seed < 20; seed++) {
        final qs = gen.generate(mode: QuizMode.random, seed: seed, count: 10);
        expect(qs, hasLength(10), reason: 'seed $seed');
      }
    });

    test('is deterministic for a given seed', () {
      final gen = QuizGenerator(eras);
      final a = gen.generate(mode: QuizMode.random, seed: 42, count: 10);
      final b = gen.generate(mode: QuizMode.random, seed: 42, count: 10);
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].type, b[i].type, reason: 'question $i');
        switch ((a[i], b[i])) {
          case (final McqQuestion x, final McqQuestion y):
            expect(x.prompt.vi, y.prompt.vi);
            expect(x.options.map((o) => o.vi), y.options.map((o) => o.vi));
            expect(x.correctIndex, y.correctIndex);
          case (final OrderQuestion x, final OrderQuestion y):
            expect(x.items.map((i) => i.eventId),
                y.items.map((i) => i.eventId));
            expect(x.correctOrder, y.correctOrder);
          default:
            fail('mismatched question shapes at $i');
        }
      }
    });

    test('different seeds give different quizzes', () {
      final gen = QuizGenerator(eras);
      final a = gen.generate(mode: QuizMode.random, seed: 1, count: 10);
      final b = gen.generate(mode: QuizMode.random, seed: 2, count: 10);
      final aIds = a.map(_sourceEventId).toList();
      final bIds = b.map(_sourceEventId).toList();
      expect(aIds, isNot(equals(bIds)));
    });

    test('every MCQ has exactly one correct option among 4 distinct ones',
        () {
      final gen = QuizGenerator(eras);
      for (var seed = 0; seed < 10; seed++) {
        final qs = gen.generate(mode: QuizMode.random, seed: seed, count: 10);
        for (final q in qs) {
          if (q is! McqQuestion) continue;
          expect(q.options, hasLength(4), reason: 'seed $seed');
          expect(q.correctIndex, inInclusiveRange(0, 3));
          final texts = q.options.map((o) => o.vi).toSet();
          expect(texts, hasLength(4),
              reason: 'options must be distinct (seed $seed): $texts');
        }
      }
    });

    test('order questions hold exactly 4 items in the correct order', () {
      final gen = QuizGenerator(eras);
      var sawOrder = false;
      for (var seed = 0; seed < 30; seed++) {
        final qs = gen.generate(mode: QuizMode.random, seed: seed, count: 10);
        for (final q in qs) {
          if (q is! OrderQuestion) continue;
          sawOrder = true;
          expect(q.items, hasLength(4));
          expect(q.correctOrder.toSet(), <int>{0, 1, 2, 3});
          final years =
              [for (final i in q.correctOrder) q.items[i].year];
          final sorted = [...years]..sort();
          expect(years, sorted, reason: 'correctOrder must sort by year');
          // The 3-year-apart rule.
          for (var i = 1; i < years.length; i++) {
            expect(years[i] - years[i - 1], greaterThanOrEqualTo(3));
          }
        }
      }
      expect(sawOrder, isTrue, reason: 'expected at least one order question '
          'across 30 seeds');
    });

    test('never asks "who" about an excluded post-1975 leader', () {
      final excludedNames = <String>{};
      for (final era in eras) {
        for (final c in era.characters) {
          if (QuizGenerator.excludedLeaderIds.contains(c.id)) {
            excludedNames.add(c.name.vi);
          }
        }
      }
      final gen = QuizGenerator(eras);
      for (var seed = 0; seed < 30; seed++) {
        final qs = gen.generate(mode: QuizMode.random, seed: seed, count: 10);
        for (final q in qs) {
          if (q is! McqQuestion || q.type != QuestionType.who) continue;
          final correctName = q.options[q.correctIndex].vi;
          expect(excludedNames.contains(correctName), isFalse,
              reason: 'seed $seed named an excluded leader: $correctName');
        }
      }
    });

    test('year options skip legend/approximate events and are 5+ years apart',
        () {
      final gen = QuizGenerator(eras);
      for (var seed = 0; seed < 15; seed++) {
        final qs = gen.generate(mode: QuizMode.random, seed: seed, count: 10);
        for (final q in qs) {
          if (q is! McqQuestion || q.type != QuestionType.year) continue;
          final years = [for (final o in q.options) _parseYearLabel(o.vi)];
          for (var i = 0; i < years.length; i++) {
            for (var j = i + 1; j < years.length; j++) {
              expect((years[i] - years[j]).abs(), greaterThanOrEqualTo(5),
                  reason: 'seed $seed: ${q.options.map((o) => o.vi)}');
            }
          }
        }
      }
    });

    test('every question resolves to a real event/era in the corpus', () {
      final byEventId = <String, Era>{};
      for (final era in eras) {
        for (final e in era.events) {
          byEventId[e.id] = era;
        }
      }
      final gen = QuizGenerator(eras);
      for (var seed = 0; seed < 20; seed++) {
        final qs = gen.generate(mode: QuizMode.random, seed: seed, count: 10);
        for (final q in qs) {
          switch (q) {
            case McqQuestion(source: final s):
              expect(byEventId.containsKey(s.eventId), isTrue,
                  reason: '${s.eventId} not a real event');
              expect(byEventId[s.eventId]!.slug, s.eraSlug);
            case OrderQuestion(items: final items):
              for (final item in items) {
                expect(byEventId.containsKey(item.eventId), isTrue,
                    reason: '${item.eventId} not a real event');
              }
          }
        }
      }
    });
  });

  group('daily mode', () {
    test('the same day always gives the same 5 questions', () {
      final gen = QuizGenerator(eras);
      final day = DateTime(2026, 9, 24);
      final a = gen.generate(mode: QuizMode.daily, seed: dailySeed(day), count: 5);
      final b = gen.generate(mode: QuizMode.daily, seed: dailySeed(day), count: 5);
      expect(a.map(_sourceEventId), b.map(_sourceEventId));
      expect(a, hasLength(5));
    });

    test('different days give different quizzes', () {
      final gen = QuizGenerator(eras);
      final a = gen.generate(
          mode: QuizMode.daily,
          seed: dailySeed(DateTime(2026, 9, 24)),
          count: 5);
      final b = gen.generate(
          mode: QuizMode.daily,
          seed: dailySeed(DateTime(2026, 9, 25)),
          count: 5);
      expect(a.map(_sourceEventId), isNot(equals(b.map(_sourceEventId))));
    });
  });

  group('byPeriod mode', () {
    test('every question traces back to that period\'s eras only', () {
      final gen = QuizGenerator(eras);
      final periodEraSlugs = eras
          .where((e) => e.period == 'doi-moi')
          .map((e) => e.slug)
          .toSet();
      final qs = gen.generate(
          mode: QuizMode.byPeriod, periodId: 'doi-moi', seed: 7, count: 10);
      expect(qs, isNotEmpty);
      for (final q in qs) {
        switch (q) {
          case McqQuestion(source: final s):
            expect(periodEraSlugs.contains(s.eraSlug), isTrue);
          case OrderQuestion(items: final items):
            for (final item in items) {
              expect(periodEraSlugs.contains(item.eraSlug), isTrue);
            }
        }
      }
    });
  });

  group('byEra mode (the quiet per-era link)', () {
    test('a real, well-populated era yields questions without throwing', () {
      final gen = QuizGenerator(eras);
      // tran-hung-dao is a flagship era with plenty of events/figures.
      final qs = gen.generate(
          mode: QuizMode.byEra, eraSlug: 'tran-hung-dao', seed: 3, count: 5);
      expect(qs, isNotEmpty);
      for (final q in qs) {
        switch (q) {
          case McqQuestion(source: final s):
            expect(s.eraSlug, 'tran-hung-dao');
          case OrderQuestion(items: final items):
            for (final item in items) {
              expect(item.eraSlug, 'tran-hung-dao');
            }
        }
      }
    });

    test('an unknown era slug yields no questions, not a crash', () {
      final gen = QuizGenerator(eras);
      final qs = gen.generate(
          mode: QuizMode.byEra, eraSlug: 'no-such-era', seed: 1, count: 5);
      expect(qs, isEmpty);
    });
  });
}
