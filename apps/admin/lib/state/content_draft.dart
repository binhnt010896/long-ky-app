import 'dart:convert';

import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_providers.dart';
import '../api/cms_api_client.dart';
import '../util/slug.dart';

/// One `GET /content` load — every `content/**/*.json` file at `main`'s
/// head, plus [baseSha]. [files] starts equal to [baseline] and diverges as
/// the admin edits; [deletedPaths] tracks removals separately since a
/// deleted path drops out of [files] entirely. [pendingChanges] is exactly
/// what `POST /commit` needs (path → new text, or null to delete).
class ContentDraft {
  const ContentDraft({
    required this.baseSha,
    required this.baseline,
    required this.files,
    required this.deletedPaths,
  });

  factory ContentDraft.fromLoad(ContentAtHead loaded) => ContentDraft(
    baseSha: loaded.sha,
    baseline: loaded.files,
    files: loaded.files,
    deletedPaths: const {},
  );

  final String baseSha;
  final Map<String, String> baseline;
  final Map<String, String> files;
  final Set<String> deletedPaths;

  bool get isDirty => pendingChanges.isNotEmpty;

  Map<String, String?> get pendingChanges {
    final out = <String, String?>{};
    for (final entry in files.entries) {
      if (baseline[entry.key] != entry.value) out[entry.key] = entry.value;
    }
    for (final path in deletedPaths) {
      out[path] = null;
    }
    return out;
  }

  ContentDraft withFile(String path, String text) => ContentDraft(
    baseSha: baseSha,
    baseline: baseline,
    files: {...files, path: text},
    deletedPaths: deletedPaths.difference({path}),
  );

  ContentDraft withDeletedFile(String path) {
    final newFiles = {...files}..remove(path);
    final wasInBaseline = baseline.containsKey(path);
    return ContentDraft(
      baseSha: baseSha,
      baseline: baseline,
      files: newFiles,
      deletedPaths: wasInBaseline ? {...deletedPaths, path} : deletedPaths,
    );
  }

  ContentDraft settled(String newSha) =>
      ContentDraft(baseSha: newSha, baseline: files, files: files, deletedPaths: const {});

  Map<String, String> get eraFiles => {
    for (final entry in files.entries)
      if (entry.key.startsWith('content/eras/') && entry.key.endsWith('.json'))
        entry.key.replaceFirst('content/eras/', ''): entry.value,
  };

  String get peopleJson => files['content/people.json']!;
  String get periodsJson => files['content/periods.json']!;
  String get indexJson => files['content/index.json']!;
  String get eraSchemaJson => files['content/era.schema.json']!;
  String get peopleSchemaJson => files['content/people.schema.json']!;
  String get periodSchemaJson => files['content/period.schema.json']!;

  /// `content/events.json` — every event, defined once (Cycle N). Tolerates a
  /// repo that predates the registry (an empty one), so the draft still loads.
  String get eventsJson =>
      files['content/events.json'] ?? '{"schemaVersion":1,"events":[]}';
  String? get eventSchemaJson => files['content/event.schema.json'];
  bool get hasEventRegistry => files.containsKey('content/events.json');

  Map<String, dynamic> get eventsDecoded => jsonDecode(eventsJson) as Map<String, dynamic>;

  /// Every event in the registry, in file order.
  List<Map<String, dynamic>> get events =>
      (eventsDecoded['events'] as List).cast<Map<String, dynamic>>();

  Map<String, dynamic>? eventById(String id) {
    for (final e in events) {
      if (e['id'] == id) return e;
    }
    return null;
  }

  /// Era slug → the ids of its events, in reading order (a `{ref}` item's
  /// `ref`, or an inlined event's `id`).
  Map<String, List<String>> get eventIdsByEra {
    final out = <String, List<String>>{};
    for (final entry in eraFiles.entries) {
      try {
        final era = jsonDecode(entry.value) as Map<String, dynamic>;
        out[entry.key.replaceAll('.json', '')] = [
          for (final item in (era['events'] as List? ?? const <dynamic>[]))
            if (item is Map<String, dynamic>)
              (item['ref'] ?? item['id']) as String,
        ];
      } catch (_) {
        // Skip an era whose draft text isn't valid JSON right now.
      }
    }
    return out;
  }

  /// The slug of the era that lists [eventId], or null if it is standalone.
  String? eraSlugOfEvent(String eventId) {
    for (final entry in eventIdsByEra.entries) {
      if (entry.value.contains(eventId)) return entry.key;
    }
    return null;
  }

  /// Registry events no era lists.
  List<Map<String, dynamic>> get standaloneEvents {
    final listed = {for (final ids in eventIdsByEra.values) ...ids};
    return [
      for (final e in events)
        if (!listed.contains(e['id'])) e,
    ];
  }

  /// People on at least one era's roster — the only people a standalone event
  /// may feature (every chip has to open a page).
  Set<String> get peopleOnAnyRoster {
    final out = <String>{};
    for (final entry in eraFiles.entries) {
      try {
        final era = jsonDecode(entry.value) as Map<String, dynamic>;
        for (final c in (era['characters'] as List? ?? const <dynamic>[])) {
          out.add((c as Map<String, dynamic>)['ref'] as String);
        }
      } catch (_) {}
    }
    return out;
  }

  /// Registry events that name [personId] in `figureIds` and belong to no era —
  /// they'd be left with a dangling figure if the person were deleted.
  List<String> standaloneEventsFeaturing(String personId) => [
        for (final e in standaloneEvents)
          if ((e['figureIds'] as List? ?? const <dynamic>[]).contains(personId))
            e['id'] as String,
      ];

  /// Everything that points at [eventId] — what a delete has to clean up.
  EventReferences referencesTo(String eventId) {
    final streets = <StreetReference>[];
    for (final entry in files.entries) {
      final path = entry.key;
      if (!path.startsWith('content/streets/') ||
          !path.endsWith('.json') ||
          path.contains('aliases')) {
        continue;
      }
      try {
        final doc = jsonDecode(entry.value) as Map<String, dynamic>;
        for (final st in (doc['streets'] as List? ?? const <dynamic>[])) {
          final street = st as Map<String, dynamic>;
          final targets = (street['targets'] as List? ?? const <dynamic>[])
              .cast<Map<String, dynamic>>();
          final hits = targets
              .where((t) => t['type'] == 'event' && t['id'] == eventId)
              .length;
          if (hits > 0) {
            streets.add(StreetReference(
              file: path,
              streetId: street['id'] as String,
              name: street['name'] as String? ?? street['id'] as String,
              losesLastTarget: targets.length == hits,
            ));
          }
        }
      } catch (_) {}
    }
    return EventReferences(
      eraSlug: eraSlugOfEvent(eventId),
      relatedFrom: [
        for (final e in events)
          if (e['id'] != eventId &&
              (e['relatedEventIds'] as List? ?? const <dynamic>[]).contains(eventId))
            e['id'] as String,
      ],
      streets: streets,
    );
  }

  Map<String, dynamic> get peopleDecoded => jsonDecode(peopleJson) as Map<String, dynamic>;
  Map<String, dynamic> get periodsDecoded => jsonDecode(periodsJson) as Map<String, dynamic>;
  Map<String, dynamic> get indexDecoded => jsonDecode(indexJson) as Map<String, dynamic>;

  List<Map<String, dynamic>> get people =>
      (peopleDecoded['people'] as List).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get periods =>
      (periodsDecoded['periods'] as List).cast<Map<String, dynamic>>();

  /// Era slugs still referencing [personId] in their `characters` roster —
  /// the delete guard for the People screen.
  List<String> erasReferencingPerson(String personId) {
    final out = <String>[];
    for (final entry in eraFiles.entries) {
      try {
        final era = jsonDecode(entry.value) as Map<String, dynamic>;
        final refs = (era['characters'] as List? ?? const [])
            .cast<Map<String, dynamic>>()
            .map((c) => c['ref'] as String);
        if (refs.contains(personId)) out.add(entry.key.replaceAll('.json', ''));
      } catch (_) {
        // Skip an era whose draft text isn't valid JSON right now.
      }
    }
    return out..sort();
  }

  /// Era slugs still in [periodId] — the delete guard for the Periods tree.
  List<String> erasInPeriod(String periodId) {
    final out = <String>[];
    for (final entry in eraFiles.entries) {
      try {
        final era = jsonDecode(entry.value) as Map<String, dynamic>;
        if (era['period'] == periodId) out.add(entry.key.replaceAll('.json', ''));
      } catch (_) {
        // Skip an era whose draft text isn't valid JSON right now.
      }
    }
    return out..sort();
  }

  ContentValidationResult validate() => ContentValidator.validateAll(
    eraSchemaJson: eraSchemaJson,
    peopleSchemaJson: peopleSchemaJson,
    periodSchemaJson: periodSchemaJson,
    eraFiles: eraFiles,
    peopleJson: peopleJson,
    periodsJson: periodsJson,
    indexJson: indexJson,
    eventSchemaJson: hasEventRegistry ? eventSchemaJson : null,
    eventsJson: hasEventRegistry && eventSchemaJson != null ? eventsJson : null,
  );
}

/// What points at one event — shown before a delete, cleaned by it.
class EventReferences {
  const EventReferences({
    required this.eraSlug,
    required this.relatedFrom,
    required this.streets,
  });

  /// The era that lists it, or null if it is standalone.
  final String? eraSlug;

  /// Other events whose `relatedEventIds` name it.
  final List<String> relatedFrom;

  /// Street-map targets that name it.
  final List<StreetReference> streets;

  bool get isEmpty => eraSlug == null && relatedFrom.isEmpty && streets.isEmpty;
}

/// One street-map street that has the event as a target.
class StreetReference {
  const StreetReference({
    required this.file,
    required this.streetId,
    required this.name,
    required this.losesLastTarget,
  });

  final String file;
  final String streetId;
  final String name;

  /// Removing the event would leave the street with no targets — so it goes
  /// too (an approved street with no targets is invalid).
  final bool losesLastTarget;
}

class ContentDraftController extends AsyncNotifier<ContentDraft> {
  @override
  Future<ContentDraft> build() async {
    final loaded = await ref.read(cmsApiClientProvider).getContent();
    return ContentDraft.fromLoad(loaded);
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final loaded = await ref.read(cmsApiClientProvider).getContent();
      return ContentDraft.fromLoad(loaded);
    });
  }

  void _update(ContentDraft Function(ContentDraft) f) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(f(current));
  }

  /// Formats [text] to canonical layout before staging it, so a save
  /// always diffs as just the field that changed — the same rule
  /// `tool/format_content.dart` enforces in CI. Used for both new files and
  /// edits to existing ones.
  void editFile(String path, String text) {
    final canonical = ContentFormatter.reformat(text);
    _update((d) => d.withFile(path, canonical));
  }

  void editDecoded(String path, Object? decoded) {
    _update((d) => d.withFile(path, ContentFormatter.format(decoded)));
  }

  void deleteFile(String path) => _update((d) => d.withDeletedFile(path));

  // --- People -------------------------------------------------------------

  /// Suggests an id from a display name; the caller should still let the
  /// admin confirm/edit it before creation, then it's locked forever.
  String suggestPersonId(String name) => slugify(name);

  void addPerson(Map<String, dynamic> person) {
    _update((d) {
      final decoded = d.peopleDecoded;
      final list = (decoded['people'] as List).cast<Map<String, dynamic>>();
      decoded['people'] = [...list, person];
      return d.withFile('content/people.json', ContentFormatter.format(decoded));
    });
  }

  void updatePerson(String id, Map<String, dynamic> Function(Map<String, dynamic>) update) {
    _update((d) {
      final decoded = d.peopleDecoded;
      final list = (decoded['people'] as List).cast<Map<String, dynamic>>();
      decoded['people'] = [
        for (final p in list) if (p['id'] == id) update({...p}) else p,
      ];
      return d.withFile('content/people.json', ContentFormatter.format(decoded));
    });
  }

  /// Throws [StateError] if any era still references this person — call
  /// [ContentDraft.erasReferencingPerson] first and show that list instead.
  void deletePerson(String id) {
    final current = state.requireValue;
    final refs = current.erasReferencingPerson(id);
    final events = current.standaloneEventsFeaturing(id);
    if (refs.isNotEmpty || events.isNotEmpty) {
      throw StateError('Referenced by: ${[...refs, ...events].join(', ')}');
    }
    _update((d) {
      final decoded = d.peopleDecoded;
      final list = (decoded['people'] as List).cast<Map<String, dynamic>>();
      decoded['people'] = list.where((p) => p['id'] != id).toList();
      return d.withFile('content/people.json', ContentFormatter.format(decoded));
    });
  }

  // --- Periods --------------------------------------------------------------

  String suggestPeriodId(String title) => slugify(title);

  void addPeriod(Map<String, dynamic> period) {
    _update((d) {
      final decoded = d.periodsDecoded;
      final list = (decoded['periods'] as List).cast<Map<String, dynamic>>();
      period['order'] = list.length;
      decoded['periods'] = [...list, period];
      return d.withFile('content/periods.json', ContentFormatter.format(decoded));
    });
  }

  void updatePeriod(String id, Map<String, dynamic> Function(Map<String, dynamic>) update) {
    _update((d) {
      final decoded = d.periodsDecoded;
      final list = (decoded['periods'] as List).cast<Map<String, dynamic>>();
      decoded['periods'] = [
        for (final p in list) if (p['id'] == id) update({...p}) else p,
      ];
      return d.withFile('content/periods.json', ContentFormatter.format(decoded));
    });
  }

  /// Throws [StateError] if the period still has eras — move or delete
  /// those first (call [ContentDraft.erasInPeriod] to show them).
  void deletePeriod(String id) {
    final current = state.requireValue;
    final eras = current.erasInPeriod(id);
    if (eras.isNotEmpty) {
      throw StateError('Still has eras: ${eras.join(', ')}');
    }
    _update((d) {
      final decoded = d.periodsDecoded;
      final list = (decoded['periods'] as List).cast<Map<String, dynamic>>();
      final remaining = list.where((p) => p['id'] != id).toList()
        ..sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));
      for (var i = 0; i < remaining.length; i++) {
        remaining[i]['order'] = i;
      }
      decoded['periods'] = remaining;
      return d.withFile('content/periods.json', ContentFormatter.format(decoded));
    });
  }

  /// Moves [id] to [newIndex] among the other periods, renumbering `order`
  /// for every period whose position actually changed.
  void reorderPeriod(String id, int newIndex) {
    _update((d) {
      final decoded = d.periodsDecoded;
      final list = (decoded['periods'] as List).cast<Map<String, dynamic>>().toList()
        ..sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));
      final moving = list.removeAt(list.indexWhere((p) => p['id'] == id));
      list.insert(newIndex.clamp(0, list.length), moving);
      for (var i = 0; i < list.length; i++) {
        list[i]['order'] = i;
      }
      decoded['periods'] = list;
      return d.withFile('content/periods.json', ContentFormatter.format(decoded));
    });
  }

  // --- Eras -----------------------------------------------------------------

  /// Creates `content/eras/<slug>.json` and lists it in `index.json`. The
  /// era's global `order` is appended after the current max.
  void addEra(Map<String, dynamic> era) {
    final current = state.requireValue;
    final slug = era['slug'] as String;
    final maxOrder = current.eraFiles.values.fold<int>(-1, (max, text) {
      try {
        final o = (jsonDecode(text) as Map<String, dynamic>)['order'] as int;
        return o > max ? o : max;
      } catch (_) {
        return max;
      }
    });
    era['order'] = maxOrder + 1;
    _update((d) {
      // Events handed in inline (the new-era dialog's placeholder) go to the
      // registry, and the era lists them by ref — the only shape the repo uses.
      final inline = (era['events'] as List? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .where((e) => !e.containsKey('ref'))
          .toList();
      if (inline.isNotEmpty) {
        final entries = [
          for (final e in inline) <String, dynamic>{...e, 'slug': e['id']}..remove('order'),
        ];
        d = _withEvents(d, [...d.events, ...entries]);
        era['events'] = [
          for (final e in inline) <String, dynamic>{'ref': e['id']},
        ];
      }
      var next = d.withFile('content/eras/$slug.json', ContentFormatter.format(era));
      final index = next.indexDecoded;
      final eras = (index['eras'] as List).cast<String>();
      index['eras'] = [...eras, slug];
      next = next.withFile('content/index.json', ContentFormatter.format(index));
      return next;
    });
  }

  void updateEra(String slug, Map<String, dynamic> Function(Map<String, dynamic>) update) {
    _update((d) {
      final path = 'content/eras/$slug.json';
      final decoded = jsonDecode(d.files[path]!) as Map<String, dynamic>;
      final updated = update({...decoded});
      return d.withFile(path, ContentFormatter.format(updated));
    });
  }

  void deleteEra(String slug) {
    _update((d) {
      var next = d.withDeletedFile('content/eras/$slug.json');
      final index = next.indexDecoded;
      final eras = (index['eras'] as List).cast<String>();
      index['eras'] = eras.where((s) => s != slug).toList();
      next = next.withFile('content/index.json', ContentFormatter.format(index));
      return next;
    });
  }

  /// Moves [slug] to a new [period] (rewrites the era's own `period` field
  /// only — its `order` is unchanged, since order is global, not
  /// per-period).
  void moveEraToPeriod(String slug, String period) {
    updateEra(slug, (era) {
      era['period'] = period;
      return era;
    });
  }

  /// Swaps [slug]'s `order` with the era immediately before/after it in
  /// the full era listing — used by the tree's up/down reorder controls.
  /// Renumbering is local to the swap, so unrelated eras are never
  /// rewritten.
  void nudgeEraOrder(String slug, {required bool up}) {
    _update((d) {
      final entries = d.eraFiles.entries.toList();
      final decoded = <String, Map<String, dynamic>>{
        for (final e in entries)
          if (_tryDecode(e.value) != null) e.key: _tryDecode(e.value)!,
      };
      final sorted = decoded.entries.toList()
        ..sort((a, b) => (a.value['order'] as int).compareTo(b.value['order'] as int));
      final index = sorted.indexWhere((e) => e.key == '$slug.json');
      if (index == -1) return d;
      final swapWith = up ? index - 1 : index + 1;
      if (swapWith < 0 || swapWith >= sorted.length) return d;

      final a = sorted[index];
      final b = sorted[swapWith];
      final aOrder = a.value['order'];
      final bOrder = b.value['order'];
      var next = d;
      final aUpdated = {...a.value, 'order': bOrder};
      final bUpdated = {...b.value, 'order': aOrder};
      next = next.withFile('content/eras/${a.key}', ContentFormatter.format(aUpdated));
      next = next.withFile('content/eras/${b.key}', ContentFormatter.format(bUpdated));
      return next;
    });
  }

  Map<String, dynamic>? _tryDecode(String text) {
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // --- Events -----------------------------------------------------------
  //
  // Since Cycle N an event is defined once in `content/events.json`; an era
  // lists the events it contains as `{"ref": id}` items (list position = reading
  // order) and an event no era lists is *standalone*. Every operation below keeps
  // the two sides consistent, so a draft built only through them never trips
  // the validator's event rules.

  /// Suggests an id from a title, like [suggestPersonId]/[suggestPeriodId].
  /// An event's id is also its `slug` (the validator enforces the two match) —
  /// both are set from this suggestion when an event is created.
  String suggestEventId(String title) => slugify(title);

  ContentDraft _withEvents(ContentDraft d, List<Map<String, dynamic>> events) {
    final decoded = d.hasEventRegistry
        ? d.eventsDecoded
        : <String, dynamic>{'schemaVersion': 1};
    decoded['events'] = events;
    return d.withFile('content/events.json', ContentFormatter.format(decoded));
  }

  ContentDraft _withEraEvents(ContentDraft d, String eraSlug, List<dynamic> items) {
    final path = 'content/eras/$eraSlug.json';
    final era = jsonDecode(d.files[path]!) as Map<String, dynamic>;
    era['events'] = items;
    return d.withFile(path, ContentFormatter.format(era));
  }

  List<dynamic> _eraItems(ContentDraft d, String eraSlug) {
    final era = jsonDecode(d.files['content/eras/$eraSlug.json']!) as Map<String, dynamic>;
    return (era['events'] as List? ?? const <dynamic>[]).toList();
  }

  static bool _isRefTo(dynamic item, String id) =>
      item is Map && (item['ref'] ?? item['id']) == id;

  /// Creates a new event in the registry and lists it at the end of
  /// `content/eras/<eraSlug>.json`. `id`/`slug` are both set to [id]; there is
  /// no `order` — the list position is the order.
  void addEvent(String eraSlug, String id, Map<String, dynamic> event) {
    _update((d) {
      final registry = d.events.toList();
      final entry = <String, dynamic>{...event, 'id': id, 'slug': id}..remove('order');
      var next = _withEvents(d, [...registry, entry]);
      next = _withEraEvents(next, eraSlug, [
        ..._eraItems(next, eraSlug),
        <String, dynamic>{'ref': id},
      ]);
      return next;
    });
  }

  /// Creates a standalone event — in the registry, listed by no era.
  void addStandaloneEvent(String id, Map<String, dynamic> event) {
    _update((d) {
      final entry = <String, dynamic>{...event, 'id': id, 'slug': id}..remove('order');
      return _withEvents(d, [...d.events, entry]);
    });
  }

  /// Edits one event wherever it lives. [update] gets a copy; the event's
  /// `id` and `order` are never changed here (the id is permanent, and the
  /// list position is the order).
  void updateEvent(String eventId, Map<String, dynamic> Function(Map<String, dynamic>) update) {
    _update((d) {
      final registry = d.events;
      if (!registry.any((e) => e['id'] == eventId)) return d;
      return _withEvents(d, [
        for (final e in registry)
          if (e['id'] == eventId)
            <String, dynamic>{...update({...e}), 'id': eventId}..remove('order')
          else
            e,
      ]);
    });
  }

  /// Removes the event from the registry and from the era that lists it, drops
  /// it from every other event's `relatedEventIds`, and from every street
  /// that names it (a street left with no targets goes too — an approved
  /// street with none is invalid). Call [ContentDraft.referencesTo] first to
  /// show the admin exactly what will change.
  void deleteEvent(String eventId) {
    _update((d) {
      final refs = d.referencesTo(eventId);
      final registry = <Map<String, dynamic>>[];
      for (final e in d.events) {
        if (e['id'] == eventId) continue;
        final related = (e['relatedEventIds'] as List? ?? const <dynamic>[])
            .cast<String>()
            .where((r) => r != eventId)
            .toList();
        final copy = {...e};
        if (related.isEmpty) {
          copy.remove('relatedEventIds');
        } else {
          copy['relatedEventIds'] = related;
        }
        registry.add(copy);
      }
      var next = _withEvents(d, registry);
      final era = refs.eraSlug;
      if (era != null) {
        next = _withEraEvents(next, era, [
          for (final item in _eraItems(next, era))
            if (!_isRefTo(item, eventId)) item,
        ]);
      }
      for (final file in {for (final s in refs.streets) s.file}) {
        final doc = jsonDecode(next.files[file]!) as Map<String, dynamic>;
        final streets = <dynamic>[];
        for (final st in (doc['streets'] as List).cast<Map<String, dynamic>>()) {
          final targets = (st['targets'] as List? ?? const <dynamic>[])
              .cast<Map<String, dynamic>>()
              .where((t) => !(t['type'] == 'event' && t['id'] == eventId))
              .toList();
          if (targets.isEmpty && (st['targets'] as List? ?? const []).isNotEmpty) continue;
          streets.add({...st, 'targets': targets});
        }
        doc['streets'] = streets;
        next = next.withFile(file, ContentFormatter.format(doc));
      }
      return next;
    });
  }

  /// Every event whose `relatedEventIds` names [eventId] — the CMS shows this
  /// before a delete so the admin knows what will change.
  List<String> eventsReferencing(String eventId) =>
      state.valueOrNull?.referencesTo(eventId).relatedFrom ?? const [];

  /// Moves the event at [eventId] to [newIndex] among its era's other events.
  void reorderEvent(String eraSlug, String eventId, int newIndex) {
    _update((d) {
      final items = _eraItems(d, eraSlug);
      final from = items.indexWhere((i) => _isRefTo(i, eventId));
      if (from == -1) return d;
      final moving = items.removeAt(from);
      items.insert(newIndex.clamp(0, items.length), moving);
      return _withEraEvents(d, eraSlug, items);
    });
  }

  /// Takes the event out of the era that lists it; it becomes a standalone
  /// event (never deleted). Throws [StateError] if it is the era's only event —
  /// an era keeps at least one.
  void removeEventFromEra(String eventId) {
    final d = state.requireValue;
    final era = d.eraSlugOfEvent(eventId);
    if (era == null) return;
    if (_eraItems(d, era).length <= 1) {
      throw StateError('An era needs at least one event');
    }
    _update((d) => _withEraEvents(d, era, [
          for (final item in _eraItems(d, era))
            if (!_isRefTo(item, eventId)) item,
        ]));
  }

  /// Lists the event at the end of [eraSlug], taking it out of whichever era
  /// lists it now (or out of the standalone pool). An event is in at most one
  /// era. People it features who aren't on [eraSlug]'s roster are added, so its
  /// figure chips still resolve. Throws [StateError] if leaving would empty the
  /// era it comes from.
  void moveEventToEra(String eventId, String eraSlug) {
    final current = state.requireValue;
    final from = current.eraSlugOfEvent(eventId);
    if (from == eraSlug) return;
    if (from != null && _eraItems(current, from).length <= 1) {
      throw StateError('An era needs at least one event');
    }
    _update((d) {
      var next = d;
      if (from != null) {
        next = _withEraEvents(next, from, [
          for (final item in _eraItems(next, from))
            if (!_isRefTo(item, eventId)) item,
        ]);
      }
      return _withEraEvents(next, eraSlug, [
        ..._eraItems(next, eraSlug),
        <String, dynamic>{'ref': eventId},
      ]);
    });
    final figures = (current.eventById(eventId)?['figureIds'] as List? ?? const <dynamic>[])
        .cast<String>();
    for (final id in figures) {
      ensureInRoster(eraSlug, id);
    }
  }

  /// Adds [personId] to the era's `characters` roster as a plain `{ref}`
  /// entry (no per-era overrides) if it isn't already there — used when an
  /// event's Figures picker chooses someone outside the current roster, so
  /// the figureId the event needs always resolves (the K7 validator
  /// requires it).
  void ensureInRoster(String eraSlug, String personId) {
    _update((d) {
      final path = 'content/eras/$eraSlug.json';
      final era = jsonDecode(d.files[path]!) as Map<String, dynamic>;
      final roster = (era['characters'] as List? ?? const <dynamic>[])
          .cast<Map<String, dynamic>>();
      if (roster.any((c) => c['ref'] == personId)) return d;
      era['characters'] = [
        ...roster,
        <String, dynamic>{'ref': personId},
      ];
      return d.withFile(path, ContentFormatter.format(era));
    });
  }

  /// Commits every pending edit as one atomic commit, then folds the new
  /// head sha back into the draft as its new baseline. Throws
  /// [CommitConflictException] if `main` moved — the caller should show
  /// that and offer [reload], not retry blindly.
  Future<void> commit(String message) async {
    final current = state.requireValue;
    if (!current.isDirty) return;
    final newSha = await ref
        .read(cmsApiClientProvider)
        .commit(baseSha: current.baseSha, files: current.pendingChanges, message: message);
    state = AsyncData(current.settled(newSha));
  }
}

final contentDraftProvider = AsyncNotifierProvider<ContentDraftController, ContentDraft>(
  ContentDraftController.new,
);
