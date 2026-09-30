import 'package:meta/meta.dart';

import 'history_event.dart';
import 'json_util.dart';

/// Every event, keyed by id — `content/events.json`.
///
/// The same pattern as [PeopleRegistry]: an event is defined once here and an
/// era lists the ones it contains as `{"ref": "<id>"}` items, in reading
/// order. An event no era lists is a *standalone* event.
///
/// Events in the registry carry no `order` (their position in an era's list
/// is their order), so they parse with order 0; [Era.fromJson] re-stamps it.
@immutable
class EventRegistry {
  const EventRegistry(this.events);

  /// In file order.
  final List<HistoryEvent> events;

  /// No events — for callers whose eras inline everything (a content pack, a
  /// test fixture).
  static const EventRegistry empty = EventRegistry(<HistoryEvent>[]);

  factory EventRegistry.fromJson(Map<String, dynamic> json) {
    return EventRegistry(List<HistoryEvent>.unmodifiable(
      json.list<HistoryEvent>(
        'events',
        (m, at) => HistoryEvent.fromJson(m, at, 0),
        at: 'events',
      ),
    ));
  }

  HistoryEvent? operator [](String id) {
    for (final e in events) {
      if (e.id == id) return e;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is EventRegistry &&
      other.events.length == events.length &&
      Iterable<int>.generate(events.length)
          .every((i) => other.events[i] == events[i]);

  @override
  int get hashCode => Object.hashAll(events);
}
