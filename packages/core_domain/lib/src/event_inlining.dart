import 'json_util.dart';

/// Pure-JSON helpers for the event registry (`content/events.json`).
///
/// An era file lists its events as `{"ref": "<id>"}` items; everything that
/// needs the full event — a phone reading a content pack, the validator, the
/// migration's round-trip check — inlines it first. Doing that at the JSON
/// level (not only in [Era.fromJson]) keeps one rule for every consumer:
/// *list position is the order*, and what an old app sees is exactly the
/// shape it always parsed — a full event with an integer `order`.

/// Maps each event's id to its JSON object, in file order. Throws
/// [ContentFormatException] on a missing or duplicate id.
Map<String, Map<String, dynamic>> eventJsonById(Map<String, dynamic> eventsJson) {
  final list = eventsJson['events'];
  if (list is! List) {
    throw ContentFormatException('missing required list `events`',
        path: 'events');
  }
  final out = <String, Map<String, dynamic>>{};
  for (var i = 0; i < list.length; i++) {
    final e = list[i];
    if (e is! Map<String, dynamic>) {
      throw ContentFormatException('element is not an object',
          path: 'events[$i]');
    }
    final id = e['id'];
    if (id is! String || id.isEmpty) {
      throw ContentFormatException('missing event `id`', path: 'events[$i]');
    }
    if (out.containsKey(id)) {
      throw ContentFormatException('duplicate event id `$id`',
          path: 'events[$i]');
    }
    out[id] = e;
  }
  return out;
}

/// Whether an era's `events` item is a `{ref}` rather than an inlined event.
bool isEventRef(Object? item) =>
    item is Map<String, dynamic> && item.containsKey('ref');

/// A copy of [event] with `order` set to [order], placed right before `kind`
/// — where every authored event already keeps it — so a re-inlined event
/// reads like the hand-authored one did.
Map<String, dynamic> withOrderKey(Map<String, dynamic> event, int order) {
  final out = <String, dynamic>{};
  var placed = false;
  for (final entry in event.entries) {
    if (entry.key == 'order') continue;
    if (entry.key == 'kind' && !placed) {
      out['order'] = order;
      placed = true;
    }
    out[entry.key] = entry.value;
  }
  if (!placed) out['order'] = order;
  return out;
}

/// [eraJson] with every `{ref}` item replaced by the registry's event plus
/// `order` = its position in the era's list. Already-inlined events are left
/// as they are, so this is safe on a pack-style era too. Throws
/// [ContentFormatException] on a ref the registry doesn't have.
Map<String, dynamic> inlineEraEvents(
  Map<String, dynamic> eraJson,
  Map<String, Map<String, dynamic>> eventsById,
) {
  final list = eraJson['events'];
  if (list is! List || !list.any(isEventRef)) return eraJson;
  final inlined = <dynamic>[];
  for (var i = 0; i < list.length; i++) {
    final item = list[i];
    if (!isEventRef(item)) {
      inlined.add(item);
      continue;
    }
    final id = (item as Map<String, dynamic>)['ref'];
    final event = id is String ? eventsById[id] : null;
    if (event == null) {
      throw ContentFormatException(
        'unknown event ref `$id` (not in content/events.json)',
        path: 'events[$i]',
      );
    }
    inlined.add(withOrderKey(event, i));
  }
  return <String, dynamic>{...eraJson, 'events': inlined};
}

/// The ids of registry events no era lists — the standalone events — in
/// registry order.
List<String> standaloneEventIds(
  Iterable<Map<String, dynamic>> eraJsons,
  Iterable<String> allEventIds,
) {
  final used = <String>{
    for (final era in eraJsons)
      for (final item in (era['events'] as List? ?? const <dynamic>[]))
        if (item is Map<String, dynamic>)
          if (isEventRef(item)) item['ref'] as String else item['id'] as String,
  };
  return <String>[
    for (final id in allEventIds)
      if (!used.contains(id)) id,
  ];
}
