import 'dart:math' as math;

import 'package:meta/meta.dart';

/// A date in the Vietnamese lunar calendar.
@immutable
class LunarDate {
  const LunarDate({
    required this.day,
    required this.month,
    required this.year,
    required this.leap,
  });

  final int day;
  final int month;
  final int year;

  /// True when [month] is the leap (intercalary) repeat of that month.
  final bool leap;

  @override
  bool operator ==(Object other) =>
      other is LunarDate &&
      other.day == day &&
      other.month == month &&
      other.year == year &&
      other.leap == leap;

  @override
  int get hashCode => Object.hash(day, month, year, leap);

  @override
  String toString() => '$day/$month${leap ? ' (leap)' : ''}/$year';
}

/// The Vietnamese lunar date of the solar (Gregorian) day [date]; only its
/// year, month and day are read.
///
/// This is Hồ Ngọc Đức's astronomical algorithm ("Computing the Vietnamese
/// lunar calendar", https://informatik.uni-leipzig.de/~duc/amlich/), computed
/// for UTC+7. Do not swap in a Chinese-calendar library: the Chinese calendar
/// uses UTC+8, and the two differ on some dates (Vietnam's Tết fell a month
/// before China's in 1985). Valid for the Gregorian era (after 1582).
LunarDate solarToLunar(DateTime date) =>
    _convertSolar2Lunar(date.day, date.month, date.year, _kTimeZone);

const double _kTimeZone = 7.0;
const double _kSynodicMonth = 29.530588853;

int _int(num d) => d.floor();

int _jdFromDate(int dd, int mm, int yy) {
  final a = _int((14 - mm) / 12);
  final y = yy + 4800 - a;
  final m = mm + 12 * a - 3;
  var jd = dd +
      _int((153 * m + 2) / 5) +
      365 * y +
      _int(y / 4) -
      _int(y / 100) +
      _int(y / 400) -
      32045;
  if (jd < 2299161) {
    jd = dd + _int((153 * m + 2) / 5) + 365 * y + _int(y / 4) - 32083;
  }
  return jd;
}

/// Julian day of the [k]-th new moon since 1900-01-01 (Meeus).
double _newMoon(int k) {
  final t = k / 1236.85;
  final t2 = t * t;
  final t3 = t2 * t;
  const dr = math.pi / 180;
  var jd1 = 2415020.75933 + 29.53058868 * k + 0.0001178 * t2 - 0.000000155 * t3;
  jd1 += 0.00033 * math.sin((166.56 + 132.87 * t - 0.009173 * t2) * dr);
  final m = 359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3;
  final mpr = 306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3;
  final f = 21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3;
  var c1 = (0.1734 - 0.000393 * t) * math.sin(m * dr) +
      0.0021 * math.sin(2 * dr * m);
  c1 += -0.4068 * math.sin(mpr * dr) + 0.0161 * math.sin(dr * 2 * mpr);
  c1 -= 0.0004 * math.sin(dr * 3 * mpr);
  c1 += 0.0104 * math.sin(dr * 2 * f) - 0.0051 * math.sin(dr * (m + mpr));
  c1 += -0.0074 * math.sin(dr * (m - mpr)) + 0.0004 * math.sin(dr * (2 * f + m));
  c1 += -0.0004 * math.sin(dr * (2 * f - m)) -
      0.0006 * math.sin(dr * (2 * f + mpr));
  c1 += 0.0010 * math.sin(dr * (2 * f - mpr)) +
      0.0005 * math.sin(dr * (2 * mpr + m));
  final double deltat;
  if (t < -11) {
    deltat = 0.001 +
        0.000839 * t +
        0.0002261 * t2 -
        0.00000845 * t3 -
        0.000000081 * t * t3;
  } else {
    deltat = -0.000278 + 0.000265 * t + 0.000262 * t2;
  }
  return jd1 + c1 - deltat;
}

/// The Sun's ecliptic longitude at Julian day [jdn], in radians [0, 2π).
double _sunLongitude(double jdn) {
  final t = (jdn - 2451545.0) / 36525;
  final t2 = t * t;
  const dr = math.pi / 180;
  final m = 357.52910 + 35999.05030 * t - 0.0001559 * t2 - 0.00000048 * t * t2;
  final l0 = 280.46645 + 36000.76983 * t + 0.0003032 * t2;
  var dl = (1.914600 - 0.004817 * t - 0.000014 * t2) * math.sin(dr * m);
  dl += (0.019993 - 0.000101 * t) * math.sin(dr * 2 * m) +
      0.000290 * math.sin(dr * 3 * m);
  var l = (l0 + dl) * dr;
  l -= math.pi * 2 * _int(l / (math.pi * 2));
  return l;
}

/// Which of the 12 major solar terms (0–11) the Sun is in at local midnight
/// starting day [dayNumber].
int _sunLongitudeTerm(int dayNumber, double timeZone) =>
    _int(_sunLongitude(dayNumber - 0.5 - timeZone / 24.0) / math.pi * 6);

int _newMoonDay(int k, double timeZone) =>
    _int(_newMoon(k) + 0.5 + timeZone / 24.0);

/// The day the 11th lunar month (the one holding the winter solstice) starts,
/// in the solar year [yy].
int _lunarMonth11(int yy, double timeZone) {
  final off = _jdFromDate(31, 12, yy) - 2415021;
  final k = _int(off / _kSynodicMonth);
  var nm = _newMoonDay(k, timeZone);
  final sunLong = _sunLongitudeTerm(nm, timeZone);
  if (sunLong >= 9) nm = _newMoonDay(k - 1, timeZone);
  return nm;
}

/// Offset (in months after month 11 at [a11]) of the leap month, in a year that
/// has one.
int _leapMonthOffset(int a11, double timeZone) {
  final k = _int((a11 - 2415021.076998695) / _kSynodicMonth + 0.5);
  var i = 1;
  var arc = _sunLongitudeTerm(_newMoonDay(k + i, timeZone), timeZone);
  int last;
  do {
    last = arc;
    i++;
    arc = _sunLongitudeTerm(_newMoonDay(k + i, timeZone), timeZone);
  } while (arc != last && i < 14);
  return i - 1;
}

LunarDate _convertSolar2Lunar(int dd, int mm, int yy, double timeZone) {
  final dayNumber = _jdFromDate(dd, mm, yy);
  final k = _int((dayNumber - 2415021.076998695) / _kSynodicMonth);
  var monthStart = _newMoonDay(k + 1, timeZone);
  if (monthStart > dayNumber) monthStart = _newMoonDay(k, timeZone);
  var a11 = _lunarMonth11(yy, timeZone);
  var b11 = a11;
  int lunarYear;
  if (a11 >= monthStart) {
    lunarYear = yy;
    a11 = _lunarMonth11(yy - 1, timeZone);
  } else {
    lunarYear = yy + 1;
    b11 = _lunarMonth11(yy + 1, timeZone);
  }
  final lunarDay = dayNumber - monthStart + 1;
  final diff = _int((monthStart - a11) / 29);
  var leap = false;
  var lunarMonth = diff + 11;
  if (b11 - a11 > 365) {
    final leapMonthDiff = _leapMonthOffset(a11, timeZone);
    if (diff >= leapMonthDiff) {
      lunarMonth = diff + 10;
      if (diff == leapMonthDiff) leap = true;
    }
  }
  if (lunarMonth > 12) lunarMonth -= 12;
  if (lunarMonth >= 11 && diff < 4) lunarYear -= 1;
  return LunarDate(
      day: lunarDay, month: lunarMonth, year: lunarYear, leap: leap);
}
