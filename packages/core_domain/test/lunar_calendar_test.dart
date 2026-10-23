import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

// Expected values come from published sources, not from this implementation:
//  * Tết 2020–2030: https://en.wikipedia.org/wiki/T%E1%BA%BFt
//  * 1985 and 1847: https://en.wikipedia.org/wiki/Vietnamese_calendar
void main() {
  group('solarToLunar', () {
    test('Tết (lunar 1/1) falls on the published solar date, 2020–2030', () {
      final tet = <DateTime>[
        DateTime(2020, 1, 25), DateTime(2021, 2, 12), DateTime(2022, 2, 1), DateTime(2023, 1, 22),
        DateTime(2024, 2, 10), DateTime(2025, 1, 29), DateTime(2026, 2, 17), DateTime(2027, 2, 6),
        DateTime(2028, 1, 26), DateTime(2029, 2, 13), DateTime(2030, 2, 2),
      ];
      for (final day in tet) {
        final l = solarToLunar(day);
        expect(
            (l.day, l.month, l.year, l.leap), (1, 1, day.year, false),
            reason: '$day');
      }
    });

    test('the day before Tết is the last day of month 12 of the old year', () {
      final l = solarToLunar(DateTime(2024, 2, 9));
      expect(l.month, 12);
      expect(l.year, 2023);
      expect(l.day, anyOf(29, 30));
    });

    test('1985: Vietnam keeps Tết on 21 January, a month before China', () {
      expect(solarToLunar(DateTime(1985, 1, 21)),
          const LunarDate(day: 1, month: 1, year: 1985, leap: false));
      // 20 February is the *Chinese* new year; in Vietnam it is the next month.
      final feb20 = solarToLunar(DateTime(1985, 2, 20));
      expect(feb20, isNot(const LunarDate(day: 1, month: 1, year: 1985, leap: false)));
    });

    test('1 July 1847 lunar is 11 August 1847', () {
      final l = solarToLunar(DateTime(1847, 8, 11));
      expect((l.day, l.month, l.year, l.leap), (1, 7, 1847, false));
    });

    test('days advance one at a time and a month has 29 or 30 days', () {
      var prev = solarToLunar(DateTime(2023, 1, 1));
      var days = 0;
      for (var i = 1; i <= 800; i++) {
        final cur = solarToLunar(DateTime(2023, 1, 1 + i));
        if (cur.month == prev.month && cur.leap == prev.leap) {
          expect(cur.day, prev.day + 1);
        } else {
          expect(cur.day, 1);
          expect(prev.day, anyOf(29, 30));
        }
        prev = cur;
        days++;
      }
      expect(days, 800);
    });

    test('2023 has a leap month 2 (a 13-month year)', () {
      var leapDays = 0;
      for (var i = 0; i < 366; i++) {
        final l = solarToLunar(DateTime(2023, 1, 1 + i));
        if (l.leap) {
          expect(l.month, 2);
          leapDays++;
        }
      }
      expect(leapDays, anyOf(29, 30));
    });
  });
}
