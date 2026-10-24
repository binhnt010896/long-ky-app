import 'package:meta/meta.dart';

/// The days of the streak at which the reader earns one extra unlock.
const List<int> kStreakMilestones = <int>[7, 30, 100];

/// One "giữ chuỗi" (freeze) is earned every this many streak days.
const int kStreakFreezeEvery = 7;

/// The most freezes held at once.
const int kMaxFreezes = 2;

/// A calendar date as `YYYY-MM-DD`, from the date's own fields — never from a
/// timestamp, so the time of day and the time zone can't move it.
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime? _parseDay(String? key) {
  if (key == null) return null;
  final p = key.split('-');
  if (p.length != 3) return null;
  final y = int.tryParse(p[0]), m = int.tryParse(p[1]), d = int.tryParse(p[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime.utc(y, m, d);
}

/// Whole calendar days from [from] to [to] (negative if [to] is earlier).
/// Both are taken as plain dates in UTC, so DST can't make a day 23 or 25 h.
int daysBetween(String from, String to) {
  final a = _parseDay(from), b = _parseDay(to);
  if (a == null || b == null) return 0;
  return b.difference(a).inDays;
}

/// What happened when a day was counted.
enum StreakOutcome {
  /// Already counted today, or the clock went back: nothing changes.
  unchanged,

  /// The very first day.
  started,

  /// The day after the last counted day.
  continued,

  /// One missed day, covered by a freeze.
  usedFreeze,

  /// Days were missed: the streak starts again at 1.
  reset,
}

@immutable
class StreakState {
  const StreakState({
    this.current = 0,
    this.best = 0,
    this.lastDay,
    this.freezes = 0,
  });

  /// Consecutive days counted, ending at [lastDay].
  final int current;
  final int best;

  /// The last day counted, as a [dayKey].
  final String? lastDay;
  final int freezes;

  StreakState copyWith({int? current, int? best, String? lastDay, int? freezes}) =>
      StreakState(
        current: current ?? this.current,
        best: best ?? this.best,
        lastDay: lastDay ?? this.lastDay,
        freezes: freezes ?? this.freezes,
      );

  @override
  bool operator ==(Object other) =>
      other is StreakState &&
      other.current == current &&
      other.best == best &&
      other.lastDay == lastDay &&
      other.freezes == freezes;

  @override
  int get hashCode => Object.hash(current, best, lastDay, freezes);
}

@immutable
class StreakAdvance {
  const StreakAdvance(this.state, this.outcome, {this.lost = 0, this.milestone});

  final StreakState state;
  final StreakOutcome outcome;

  /// For [StreakOutcome.reset]: the streak that was lost.
  final int lost;

  /// Set when this day reached 7, 30 or 100: that many days.
  final int? milestone;

  /// Whether this call counted a new day.
  bool get counted => outcome != StreakOutcome.unchanged;
}

abstract final class Streak {
  /// Counts [today] toward the streak.
  ///
  /// Day arithmetic on calendar dates, not hours. Counting the same day twice,
  /// or a clock set back, changes nothing. One missed day is covered by a
  /// freeze if one is held; any longer gap, or a missed day with none, resets
  /// the streak to 1 (the best is kept). A freeze is earned every
  /// [kStreakFreezeEvery] days, holding at most [kMaxFreezes].
  static StreakAdvance advance(StreakState s, DateTime today) {
    final todayKey = dayKey(today);
    final last = s.lastDay;
    if (last == null) {
      return _counted(s, todayKey, 1, s.freezes, StreakOutcome.started);
    }
    final gap = daysBetween(last, todayKey);
    if (gap <= 0) return StreakAdvance(s, StreakOutcome.unchanged);
    if (gap == 1) {
      return _counted(
          s, todayKey, s.current + 1, s.freezes, StreakOutcome.continued);
    }
    if (gap == 2 && s.freezes > 0) {
      return _counted(
          s, todayKey, s.current + 1, s.freezes - 1, StreakOutcome.usedFreeze);
    }
    return _counted(s, todayKey, 1, s.freezes, StreakOutcome.reset,
        lost: s.current);
  }

  static StreakAdvance _counted(
    StreakState s,
    String today,
    int current,
    int freezes,
    StreakOutcome outcome, {
    int lost = 0,
  }) {
    var f = freezes;
    final grew = outcome == StreakOutcome.continued ||
        outcome == StreakOutcome.usedFreeze;
    if (grew && current % kStreakFreezeEvery == 0) {
      f = f + 1 > kMaxFreezes ? kMaxFreezes : f + 1;
    }
    return StreakAdvance(
      StreakState(
        current: current,
        best: current > s.best ? current : s.best,
        lastDay: today,
        freezes: f,
      ),
      outcome,
      lost: lost,
      milestone: grew && kStreakMilestones.contains(current) ? current : null,
    );
  }
}
