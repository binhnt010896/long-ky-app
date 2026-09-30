import 'package:core_domain/core_domain.dart';

/// Where standalone events (events no era lists) sit on the global timeline
/// (Cycle N, decision N6): **right after the era group whose `startYear` is
/// the latest one that is still ≤ the event's year**, sorted by year within a
/// group. An event earlier than every era goes before the first group
/// ([beforeFirst]).
///
/// Only dated events can be placed; an undated one (the validator requires a
/// year for every standalone event, so this is defensive) is left out rather
/// than guessed at.
class StandalonePlacement {
  const StandalonePlacement(this.beforeFirst, this.afterEra);

  /// Events earlier than the first era's start.
  final List<HistoryEvent> beforeFirst;

  /// Era index (into the list passed to [place]) → the events that follow it.
  final Map<int, List<HistoryEvent>> afterEra;

  static StandalonePlacement place(
      List<Era> eras, List<HistoryEvent> standalone) {
    final before = <HistoryEvent>[];
    final after = <int, List<HistoryEvent>>{};
    for (final e in standalone) {
      final y = e.year.value;
      if (y == null) continue;
      var group = -1;
      var best = 0;
      for (var i = 0; i < eras.length; i++) {
        final start = eras[i].yearRange.startYear;
        if (start == null) continue; // an era with no numeric start anchors nothing
        // `>=` so a later era wins a tie on startYear.
        if (start <= y && (group == -1 || start >= best)) {
          group = i;
          best = start;
        }
      }
      if (group == -1) {
        before.add(e);
      } else {
        (after[group] ??= <HistoryEvent>[]).add(e);
      }
    }
    int byYear(HistoryEvent a, HistoryEvent b) =>
        a.year.value!.compareTo(b.year.value!);
    before.sort(byYear);
    for (final list in after.values) {
      list.sort(byYear);
    }
    return StandalonePlacement(before, after);
  }
}
