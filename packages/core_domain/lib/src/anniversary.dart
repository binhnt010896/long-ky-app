import 'package:meta/meta.dart';

import 'json_util.dart';

/// Which calendar an [Anniversary] is counted in.
enum AnniversaryCalendar { solar, lunar }

/// The day of the year an event is remembered on, for "Hôm nay" (on this day).
///
/// A [AnniversaryCalendar.lunar] date is the Vietnamese calendar's (see
/// `solarToLunar`) and names a regular month — never a leap one — so its day is
/// at most 30. The chronicles date most pre-modern events by the lunar
/// calendar.
@immutable
class Anniversary {
  const Anniversary({
    required this.month,
    required this.day,
    required this.calendar,
  });

  final int month;
  final int day;
  final AnniversaryCalendar calendar;

  /// Parses and range-checks, so a bad value can never reach `todayPick`. The
  /// schema checks the same ranges ahead of time; this is the in-code guard.
  factory Anniversary.fromJson(Map<String, dynamic> json,
      [String at = 'anniversary']) {
    final month = json.integer('month', at: at);
    final day = json.integer('day', at: at);
    final calendar = switch (json.str('calendar', at: at)) {
      'solar' => AnniversaryCalendar.solar,
      'lunar' => AnniversaryCalendar.lunar,
      final other => throw ContentFormatException(
          'unknown anniversary calendar `$other`',
          path: '$at.calendar'),
    };
    if (month < 1 || month > 12) {
      throw ContentFormatException('month $month is not 1–12',
          path: '$at.month');
    }
    final maxDay = switch (calendar) {
      AnniversaryCalendar.lunar => 30,
      // 29 February is allowed: it is remembered in leap years only.
      AnniversaryCalendar.solar => _solarDaysIn(month),
    };
    if (day < 1 || day > maxDay) {
      throw ContentFormatException(
          'day $day is not 1–$maxDay for a ${calendar.name} month $month',
          path: '$at.day');
    }
    return Anniversary(month: month, day: day, calendar: calendar);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'month': month,
        'day': day,
        'calendar': calendar.name,
      };

  @override
  bool operator ==(Object other) =>
      other is Anniversary &&
      other.month == month &&
      other.day == day &&
      other.calendar == calendar;

  @override
  int get hashCode => Object.hash(month, day, calendar);

  @override
  String toString() => '$day/$month (${calendar.name})';
}

/// The most days a solar [month] can have (February: 29).
int _solarDaysIn(int month) => switch (month) {
      2 => 29,
      4 || 6 || 9 || 11 => 30,
      _ => 31,
    };
