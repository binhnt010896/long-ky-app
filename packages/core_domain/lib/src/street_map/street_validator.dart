import 'dart:convert';

import 'street_map.dart';

/// Referential-integrity rules for `content/streets/<city>.json` (M-A step 4),
/// pure like [ContentValidator]. Returns human-readable problems; empty = ok.
abstract final class StreetMapValidator {
  /// [eras] are the decoded era maps; [peopleIds] the registry ids;
  /// [geometryStreetIds] the `properties.id`s in the generated GeoJSON, or
  /// null to skip the geometry cross-check. [standaloneEventIds] are the events
  /// no era lists (Cycle N): an event target with no `era` must be one of them.
  static List<String> validate({
    required String streetsJson,
    required Set<String> peopleIds,
    required List<Map<String, dynamic>> eras,
    Set<String>? geometryStreetIds,
    Set<String> standaloneEventIds = const <String>{},
  }) {
    final problems = <String>[];
    final StreetMapFile file;
    try {
      file = StreetMapFile.fromJson(jsonDecode(streetsJson) as Map<String, dynamic>);
    } catch (e) {
      return ['streets file unreadable: $e'];
    }

    final eraBySlug = {for (final e in eras) e['slug'] as String: e};
    final ids = <String>{};
    for (final s in file.streets) {
      if (!ids.add(s.id)) problems.add('street id "${s.id}" is not unique');
      if (s.isApproved && s.targets.isEmpty) {
        problems.add('street "${s.id}" is approved but has no targets');
      }
      for (final t in s.targets) {
        // An event with no era is a standalone event: it opens by id alone.
        if (t.type == StreetTargetType.event && t.era.isEmpty) {
          if (!standaloneEventIds.contains(t.id)) {
            problems.add(
                'street "${s.id}": event "${t.id}" has no era and is not a standalone event');
          }
          continue;
        }
        final era = eraBySlug[t.era];
        if (era == null) {
          problems.add('street "${s.id}": unknown era "${t.era}"');
          continue;
        }
        switch (t.type) {
          case StreetTargetType.person:
            if (!peopleIds.contains(t.id)) {
              problems.add('street "${s.id}": unknown person "${t.id}"');
            } else if (!((era['characters'] as List?) ?? const [])
                .any((c) => (c as Map<String, dynamic>)['ref'] == t.id)) {
              problems.add(
                  'street "${s.id}": person "${t.id}" is not on era "${t.era}"\'s roster');
            }
          case StreetTargetType.event:
            if (!((era['events'] as List?) ?? const [])
                .any((e) => (e as Map<String, dynamic>)['id'] == t.id)) {
              problems.add(
                  'street "${s.id}": event "${t.id}" not in era "${t.era}"');
            }
          case StreetTargetType.era:
            if (t.id != t.era) {
              problems.add('street "${s.id}": era target id "${t.id}" != era "${t.era}"');
            }
        }
      }
    }
    if (geometryStreetIds != null) {
      for (final s in file.approved) {
        if (!geometryStreetIds.contains(s.id)) {
          problems.add('approved street "${s.id}" has no geometry');
        }
      }
    }
    return problems;
  }
}
