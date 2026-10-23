import 'dart:math';

import 'package:meta/meta.dart';

import 'anniversary.dart';
import 'history_event.dart';
import 'lunar_calendar.dart';
import 'people.dart';
import 'quiz/quiz_generator.dart';

/// The keys the app uses to say "this person / event / era was visited", shared
/// by the visit store and by [todayPick]'s street preference.
abstract final class VisitKey {
  static String person(String id) => 'person:$id';
  static String event(String id) => 'event:$id';
  static String era(String slug) => 'era:$slug';
}

enum TodayKind { event, person }

/// Why an item was picked: it is remembered on this day, or it is simply the
/// day's turn in the year's rotation.
enum TodayReason { anniversary, rotation }

/// What "Hôm nay" shows today.
@immutable
class TodayItem {
  const TodayItem({
    required this.kind,
    required this.id,
    required this.reason,
    this.eventYear,
    this.yearsAgo,
  });

  final TodayKind kind;
  final String id;
  final TodayReason reason;

  /// For an anniversary: the event's year when it is an exact, common-era year.
  final int? eventYear;

  /// For an anniversary: whole years between [eventYear] and today.
  final int? yearsAgo;

  /// A round anniversary (10, 20, … years): worth saying out loud.
  bool get isRound => yearsAgo != null && yearsAgo! > 0 && yearsAgo! % 10 == 0;

  /// The [VisitKey] of the picked item.
  String get visitKey => switch (kind) {
        TodayKind.event => VisitKey.event(id),
        TodayKind.person => VisitKey.person(id),
      };

  @override
  bool operator ==(Object other) =>
      other is TodayItem &&
      other.kind == kind &&
      other.id == id &&
      other.reason == reason &&
      other.eventYear == eventYear &&
      other.yearsAgo == yearsAgo;

  @override
  int get hashCode => Object.hash(kind, id, reason, eventYear, yearsAgo);

  @override
  String toString() => 'TodayItem($kind $id, $reason, year: $eventYear)';
}

/// The one item "Hôm nay" shows on [date]. Pure and deterministic, so every
/// device on the same content shows the same thing — like the daily quiz.
///
/// 1. **Anniversary.** Events whose [HistoryEvent.anniversary] is [date] (solar),
///    or [date]'s Vietnamese lunar day and month (lunar, regular months only).
///    With several, a round number of years wins, then [dailySeed] breaks ties.
/// 2. **Rotation.** Otherwise every person and event takes a turn: the year's
///    366 slots are filled from the pool in an order seeded by the year, so
///    nothing repeats within a year. Items a street points to
///    ([streetKeys], as [VisitKey]s) fill the slots first, so the pick lights
///    up a street in most cases. Post-1975 leaders are left out
///    ([QuizGenerator.excludedLeaderIds]); their anniversary events still count.
///
/// Returns null only when there is nothing at all to show.
TodayItem? todayPick({
  required DateTime date,
  required Iterable<HistoryEvent> events,
  required PeopleRegistry people,
  Set<String> streetKeys = const <String>{},
}) {
  final byId = <String, HistoryEvent>{for (final e in events) e.id: e};

  final lunar = solarToLunar(date);
  final matches = <HistoryEvent>[
    for (final e in byId.values)
      if (_isOn(e.anniversary, date, lunar)) e,
  ];
  if (matches.isNotEmpty) {
    int? yearsAgo(HistoryEvent e) {
      final y = _exactYear(e);
      return y == null ? null : date.year - y;
    }

    final round = matches.where((e) {
      final n = yearsAgo(e);
      return n != null && n > 0 && n % 10 == 0;
    }).toList();
    final pool = round.isNotEmpty ? round : matches;
    pool.sort((a, b) => a.id.compareTo(b.id));
    final picked = pool[dailySeed(date) % pool.length];
    final year = _exactYear(picked);
    final ago = yearsAgo(picked);
    return TodayItem(
      kind: TodayKind.event,
      id: picked.id,
      reason: TodayReason.anniversary,
      eventYear: year,
      yearsAgo: ago != null && ago > 0 ? ago : null,
    );
  }

  final keys = <String>[
    for (final id in byId.keys) VisitKey.event(id),
    for (final id in people.byId.keys)
      if (!QuizGenerator.excludedLeaderIds.contains(id)) VisitKey.person(id),
  ]..sort();
  if (keys.isEmpty) return null;

  final rng = Random(date.year);
  final onStreet = <String>[
    for (final k in keys)
      if (streetKeys.contains(k)) k,
  ]..shuffle(rng);
  final others = <String>[
    for (final k in keys)
      if (!streetKeys.contains(k)) k,
  ]..shuffle(rng);
  final slots = <String>[...onStreet, ...others].take(366).toList()
    ..shuffle(rng);
  final dayOfYear =
      DateTime.utc(date.year, date.month, date.day)
          .difference(DateTime.utc(date.year, 1, 1))
          .inDays;
  final key = slots[dayOfYear % slots.length];
  final isEvent = key.startsWith('event:');
  return TodayItem(
    kind: isEvent ? TodayKind.event : TodayKind.person,
    id: key.substring(key.indexOf(':') + 1),
    reason: TodayReason.rotation,
  );
}

bool _isOn(Anniversary? a, DateTime date, LunarDate lunar) {
  if (a == null) return false;
  return switch (a.calendar) {
    AnniversaryCalendar.solar => a.month == date.month && a.day == date.day,
    AnniversaryCalendar.lunar =>
      !lunar.leap && a.month == lunar.month && a.day == lunar.day,
  };
}

/// The event's year when it is an exact common-era year.
int? _exactYear(HistoryEvent e) {
  final v = e.year.value;
  if (v == null || v <= 0 || e.year.approximate) return null;
  return v;
}
