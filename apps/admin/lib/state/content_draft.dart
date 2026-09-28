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
  );
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
    if (refs.isNotEmpty) {
      throw StateError('Referenced by: ${refs.join(', ')}');
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

  /// Suggests an id from a title, like [suggestPersonId]/[suggestPeriodId].
  /// An event's id is also its `slug` (Cycle K's validator enforces the
  /// two match) — both are set from this suggestion when an event is
  /// created.
  String suggestEventId(String title) => slugify(title);

  /// Appends a new event to `content/eras/<slug>.json`'s `events`, with
  /// `order` set to run after the existing ones and `id`/`slug` both set to
  /// [id]. Every event created this way already satisfies the validator's
  /// event-integrity rules (K7) — the id/slug pairing and a contiguous
  /// order — so only genuinely missing content (a hero image, say) can fail
  /// review afterwards.
  void addEvent(String eraSlug, String id, Map<String, dynamic> event) {
    _update((d) {
      final path = 'content/eras/$eraSlug.json';
      final era = jsonDecode(d.files[path]!) as Map<String, dynamic>;
      final events = (era['events'] as List? ?? const <dynamic>[])
          .cast<Map<String, dynamic>>()
          .toList();
      event['id'] = id;
      event['slug'] = id;
      event['order'] = events.length;
      era['events'] = [...events, event];
      return d.withFile(path, ContentFormatter.format(era));
    });
  }

  void updateEvent(
    String eraSlug,
    String eventId,
    Map<String, dynamic> Function(Map<String, dynamic>) update,
  ) {
    _update((d) {
      final path = 'content/eras/$eraSlug.json';
      final era = jsonDecode(d.files[path]!) as Map<String, dynamic>;
      final events = (era['events'] as List).cast<Map<String, dynamic>>();
      era['events'] = [
        for (final e in events)
          if (e['id'] == eventId) update({...e}) else e,
      ];
      return d.withFile(path, ContentFormatter.format(era));
    });
  }

  /// Removes the event, renumbers the remaining `order`s to stay
  /// contiguous, and drops it from every other event's `relatedEventIds` in
  /// the same era — a dangling reference is exactly what the K7 validator
  /// rejects, so this can never leave one behind. Call
  /// [eventsReferencing] first to show the admin what will be cleaned.
  void deleteEvent(String eraSlug, String eventId) {
    _update((d) {
      final path = 'content/eras/$eraSlug.json';
      final era = jsonDecode(d.files[path]!) as Map<String, dynamic>;
      final events = (era['events'] as List).cast<Map<String, dynamic>>();
      final remaining = events.where((e) => e['id'] != eventId).toList()
        ..sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));
      for (var i = 0; i < remaining.length; i++) {
        final related = (remaining[i]['relatedEventIds'] as List? ?? const <dynamic>[])
            .cast<String>()
            .where((r) => r != eventId)
            .toList();
        remaining[i] = {...remaining[i], 'order': i};
        if (related.isEmpty) {
          remaining[i].remove('relatedEventIds');
        } else {
          remaining[i]['relatedEventIds'] = related;
        }
      }
      era['events'] = remaining;
      return d.withFile(path, ContentFormatter.format(era));
    });
  }

  /// Other events in the same era whose `relatedEventIds` name [eventId] —
  /// the CMS shows this before a delete so the admin knows what will change.
  List<String> eventsReferencing(String eraSlug, String eventId) {
    final path = 'content/eras/$eraSlug.json';
    final text = state.valueOrNull?.files[path];
    if (text == null) return const [];
    final era = _tryDecode(text);
    if (era == null) return const [];
    final events = (era['events'] as List? ?? const <dynamic>[]).cast<Map<String, dynamic>>();
    return [
      for (final e in events)
        if (e['id'] != eventId &&
            (e['relatedEventIds'] as List? ?? const <dynamic>[]).contains(eventId))
          e['id'] as String,
    ];
  }

  /// Moves the event at [eventId] to [newIndex] among its era's other
  /// events, renumbering `order` for the whole era (mirrors
  /// [reorderPeriod]).
  void reorderEvent(String eraSlug, String eventId, int newIndex) {
    _update((d) {
      final path = 'content/eras/$eraSlug.json';
      final era = jsonDecode(d.files[path]!) as Map<String, dynamic>;
      final events = (era['events'] as List).cast<Map<String, dynamic>>().toList()
        ..sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));
      final moving = events.removeAt(events.indexWhere((e) => e['id'] == eventId));
      events.insert(newIndex.clamp(0, events.length), moving);
      for (var i = 0; i < events.length; i++) {
        events[i]['order'] = i;
      }
      era['events'] = events;
      return d.withFile(path, ContentFormatter.format(era));
    });
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
