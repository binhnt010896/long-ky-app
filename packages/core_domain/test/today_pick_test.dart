import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

HistoryEvent _event(String id,
        {int? year, bool approx = false, Anniversary? on}) =>
    HistoryEvent(
      id: id,
      order: 0,
      kind: EventKind.historical,
      year: YearRef(
          display: LocalizedText(vi: '$year'), value: year, approximate: approx),
      anniversary: on,
      title: LocalizedText(vi: id),
      summary: LocalizedText(vi: id),
      citation: const Citation(work: 'test'),
    );

PeopleRegistry _people(Iterable<String> ids) => PeopleRegistry(<String, Character>{
      for (final id in ids) id: Character(id: id, name: LocalizedText(vi: id)),
    });

const _solar = AnniversaryCalendar.solar;
const _lunar = AnniversaryCalendar.lunar;

void main() {
  group('Anniversary.fromJson', () {
    test('round-trips', () {
      const a = Anniversary(month: 4, day: 30, calendar: _solar);
      expect(Anniversary.fromJson(a.toJson()), a);
    });

    test('rejects impossible dates', () {
      Map<String, dynamic> j(int m, int d, String c) =>
          {'month': m, 'day': d, 'calendar': c};
      expect(() => Anniversary.fromJson(j(13, 1, 'solar')), throwsA(isA<ContentFormatException>()));
      expect(() => Anniversary.fromJson(j(4, 31, 'solar')), throwsA(isA<ContentFormatException>()));
      expect(() => Anniversary.fromJson(j(2, 30, 'solar')), throwsA(isA<ContentFormatException>()));
      expect(() => Anniversary.fromJson(j(3, 31, 'lunar')), throwsA(isA<ContentFormatException>()));
      expect(() => Anniversary.fromJson(j(3, 1, 'julian')), throwsA(isA<ContentFormatException>()));
      expect(Anniversary.fromJson(j(2, 29, 'solar')).day, 29);
      expect(Anniversary.fromJson(j(3, 30, 'lunar')).day, 30);
    });
  });

  group('HistoryEvent.anniversary', () {
    Map<String, dynamic> json([Map<String, dynamic>? a]) => {
          'id': 'x',
          'kind': 'historical',
          'year': {'display': {'vi': '1975'}, 'value': 1975},
          'title': {'vi': 'x'},
          'summary': {'vi': 'x'},
          'citation': {'work': 'w'},
          if (a != null) 'anniversary': a,
        };

    test('is optional, parsed, and survives withOrder', () {
      expect(HistoryEvent.fromJson(json(), 'e', 0).anniversary, isNull);
      final e = HistoryEvent.fromJson(
          json({'month': 4, 'day': 30, 'calendar': 'solar'}), 'e', 0);
      expect(e.anniversary, const Anniversary(month: 4, day: 30, calendar: _solar));
      expect(e.withOrder(3).anniversary, e.anniversary);
      expect(e == e.withOrder(0), isTrue);
    });

    test('a bad anniversary fails parsing', () {
      expect(
          () => HistoryEvent.fromJson(
              json({'month': 13, 'day': 1, 'calendar': 'solar'}), 'e', 0),
          throwsA(isA<ContentFormatException>()));
    });
  });

  group('todayPick', () {
    final people = _people(<String>['a', 'b', 'le-duan']);

    test('a solar anniversary wins on its day', () {
      final events = <HistoryEvent>[
        _event('thong-nhat', year: 1975, on: const Anniversary(month: 4, day: 30, calendar: _solar)),
        _event('other', year: 1000),
      ];
      final pick = todayPick(date: DateTime(2026, 4, 30), events: events, people: people)!;
      expect(pick.reason, TodayReason.anniversary);
      expect((pick.kind, pick.id), (TodayKind.event, 'thong-nhat'));
      expect(pick.eventYear, 1975);
      expect(pick.yearsAgo, 51);
      expect(pick.isRound, isFalse);
    });

    test('a round number of years is flagged and wins over a non-round one', () {
      final events = <HistoryEvent>[
        _event('a-51', year: 1975, on: const Anniversary(month: 4, day: 30, calendar: _solar)),
        _event('b-50', year: 1976, on: const Anniversary(month: 4, day: 30, calendar: _solar)),
      ];
      final pick = todayPick(date: DateTime(2026, 4, 30), events: events, people: people)!;
      expect(pick.id, 'b-50');
      expect(pick.isRound, isTrue);
    });

    test('a lunar anniversary lands on a different solar day each year', () {
      // Lunar 10/3 (Giỗ Tổ). Dates from the converter, which is tested
      // against published Tết dates in lunar_calendar_test.dart.
      final events = <HistoryEvent>[
        _event('gio-to', on: const Anniversary(month: 3, day: 10, calendar: _lunar)),
      ];
      final hits = <DateTime>[];
      for (final year in <int>[2024, 2025]) {
        var d = DateTime(year, 1, 1);
        while (d.year == year) {
          if (todayPick(date: d, events: events, people: people)!.reason ==
              TodayReason.anniversary) {
            hits.add(d);
          }
          d = DateTime(d.year, d.month, d.day + 1);
        }
      }
      expect(hits.length, 2); // exactly one day a year, not a leap month's twin
      expect(hits[0].day == hits[1].day && hits[0].month == hits[1].month, isFalse);
    });

    test('a legend with no exact year still works, with no years-ago', () {
      final events = <HistoryEvent>[
        _event('legend', on: const Anniversary(month: 3, day: 10, calendar: _solar)),
        _event('approx', year: 1000, approx: true),
      ];
      final pick = todayPick(date: DateTime(2026, 3, 10), events: events, people: people)!;
      expect(pick.eventYear, isNull);
      expect(pick.yearsAgo, isNull);
    });

    test('with no anniversary, the rotation never repeats within a year', () {
      final events = <HistoryEvent>[for (var i = 0; i < 300; i++) _event('e$i', year: 1000 + i)];
      final ppl = _people(<String>[for (var i = 0; i < 200; i++) 'p$i']);
      final seen = <String>{};
      var d = DateTime(2026, 1, 1);
      while (d.year == 2026) {
        final p = todayPick(date: d, events: events, people: ppl)!;
        expect(p.reason, TodayReason.rotation);
        expect(seen.add(p.visitKey), isTrue, reason: '$d repeats ${p.visitKey}');
        d = DateTime(d.year, d.month, d.day + 1);
      }
      expect(seen.length, 365);
    });

    test('the rotation never picks a post-1975 leader, and is deterministic', () {
      final ppl = _people(<String>['le-duan', 'to-lam', 'x', 'y']);
      final events = <HistoryEvent>[_event('e', year: 1900)];
      var d = DateTime(2026, 1, 1);
      while (d.year == 2026) {
        final a = todayPick(date: d, events: events, people: ppl)!;
        final b = todayPick(date: d, events: events, people: ppl)!;
        expect(a, b);
        expect(a.id, isNot(anyOf('le-duan', 'to-lam')));
        d = DateTime(d.year, d.month, d.day + 1);
      }
    });

    test('street-pointed items fill the slots first', () {
      final events = <HistoryEvent>[for (var i = 0; i < 400; i++) _event('e$i', year: 1000 + i)];
      final streets = <String>{for (var i = 0; i < 366; i++) VisitKey.event('e$i')};
      var d = DateTime(2024, 1, 1); // a leap year: 366 days
      var onStreet = 0;
      while (d.year == 2024) {
        final p = todayPick(date: d, events: events, people: PeopleRegistry.empty, streetKeys: streets)!;
        if (streets.contains(p.visitKey)) onStreet++;
        d = DateTime(d.year, d.month, d.day + 1);
      }
      expect(onStreet, 366);
    });

    test('nothing to show is null', () {
      expect(todayPick(date: DateTime(2026, 1, 1), events: const <HistoryEvent>[], people: PeopleRegistry.empty), isNull);
    });
  });
}
