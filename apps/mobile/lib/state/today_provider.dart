import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/streets/street_data.dart';
import 'providers.dart';

/// What "Hôm nay" shows for one day: the pick plus the words to show for it.
class TodayView {
  const TodayView({required this.item, required this.title, this.summary});

  final TodayItem item;
  final LocalizedText title;

  /// An event's one-line summary, or a person's epithet.
  final LocalizedText? summary;
}

/// The small line above the title, in [lang]: the anniversary ("Ngày này năm
/// 1975 · 50 năm") or what kind of pick it is. Pure.
String todayKicker(TodayItem item, Lang lang) {
  final en = lang == Lang.en;
  if (item.reason == TodayReason.anniversary) {
    final year = item.eventYear;
    if (year == null) return en ? 'On this day' : 'Ngày này năm xưa';
    final round = item.isRound
        ? (en ? ' · ${item.yearsAgo} years ago' : ' · ${item.yearsAgo} năm')
        : '';
    return en ? 'On this day in $year$round' : 'Ngày này năm $year$round';
  }
  return switch (item.kind) {
    TodayKind.person => en ? 'Figure of the day' : 'Nhân vật hôm nay',
    TodayKind.event => en ? 'Event of the day' : 'Sự kiện hôm nay',
  };
}

/// Everything [todayPick] needs, loaded once: the events (an era's and the
/// standalone ones, each once), the people, and the person/event keys some
/// street points at. Changes when a new content pack is adopted.
class TodayContext {
  TodayContext({
    required Iterable<HistoryEvent> events,
    required this.people,
    this.streetKeys = const <String>{},
  }) : events = <String, HistoryEvent>{for (final e in events) e.id: e}
            .values
            .toList(growable: false);

  final List<HistoryEvent> events;
  final PeopleRegistry people;
  final Set<String> streetKeys;

  TodayItem? pickFor(DateTime day) => todayPick(
        date: day,
        events: events,
        people: people,
        streetKeys: streetKeys,
      );

  /// The words for [item], or null if its event/person is no longer in the
  /// content (e.g. a pack changed under a scheduled reminder).
  TodayView? viewOf(TodayItem item) {
    switch (item.kind) {
      case TodayKind.event:
        for (final e in events) {
          if (e.id == item.id) {
            return TodayView(item: item, title: e.title, summary: e.summary);
          }
        }
      case TodayKind.person:
        final p = people[item.id];
        if (p != null) {
          return TodayView(item: item, title: p.name, summary: p.epithet);
        }
    }
    return null;
  }

  /// [pickFor] and [viewOf] together.
  TodayView? viewFor(DateTime day) {
    final item = pickFor(day);
    return item == null ? null : viewOf(item);
  }
}

final todayContextProvider = FutureProvider<TodayContext>((ref) async {
  final eras = await ref.watch(erasProvider.future);
  // Optional inputs must never cost the reader the feature.
  final standalone = await ref
      .watch(standaloneEventsProvider.future)
      .catchError((Object _) => const <HistoryEvent>[]);
  final people = await ref
      .watch(peopleProvider.future)
      .catchError((Object _) => PeopleRegistry.empty);
  final mapping = await ref
      .watch(streetMappingProvider.future)
      .catchError((Object _) => null);
  return TodayContext(
    events: <HistoryEvent>[
      for (final era in eras) ...era.events,
      ...standalone,
    ],
    people: people,
    streetKeys: mapping == null
        ? const <String>{}
        : streetPickKeys(mapping.approved),
  );
});

/// Today's pick for the Sảnh card. Re-resolved each time the Sảnh opens, so a
/// session left open overnight shows the new day.
final todayViewProvider = FutureProvider.autoDispose<TodayView?>((ref) async {
  final ctx = await ref.watch(todayContextProvider.future);
  return ctx.viewFor(DateTime.now());
});
