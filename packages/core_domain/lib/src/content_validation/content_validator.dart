import 'dart:convert';

import 'package:json_schema/json_schema.dart';

import '../event_inlining.dart';
import '../json_util.dart' show ContentFormatException;

/// One validation failure, tied to the file it came from — e.g. the CMS's
/// per-era validation badge groups these by [file].
class ContentIssue {
  const ContentIssue(this.file, this.message);

  final String file;
  final String message;

  @override
  String toString() => '$file: $message';
}

/// The result of [ContentValidator.validateAll] — both a structured
/// [issues] list (for a UI like the CMS's dashboard) and the exact
/// human-readable [lines] `tool/validate_content.dart` has always printed,
/// so extracting this out of the CLI script changed no CLI output.
class ContentValidationResult {
  const ContentValidationResult({
    required this.lines,
    required this.issues,
    required this.peopleCount,
    required this.periodCount,
    required this.eraCount,
    this.eventCount = 0,
    this.standaloneEventCount = 0,
  });

  final List<String> lines;
  final List<ContentIssue> issues;
  final int peopleCount;
  final int periodCount;
  final int eraCount;

  /// Events in `events.json` (0 when no registry was supplied) and how many
  /// of those no era lists.
  final int eventCount;
  final int standaloneEventCount;

  bool get isValid => issues.isEmpty;
}

/// Validates `content/`'s era/people/period JSON against their schemas, plus
/// the referential-integrity rules the schemas alone can't express (a
/// character ref must exist in the people registry, an event's figureIds
/// must be part of that era's own roster, an era's period must exist in the
/// period registry, and `index.json` must list exactly the eras on disk).
///
/// Events may live in `events.json` (an era lists `{ref}` items) or inline in
/// an era. An event no era lists is *standalone*: it needs a dated `year`, a
/// `hero`, and figures from the people registry; every event, in an era
/// or not, needs a citation (the schema requires it).
///
/// Pure — takes raw JSON text/maps in, never touches the filesystem — so
/// `tool/validate_content.dart` (reading from disk) and the CMS (reading a
/// draft from memory, before anything is saved) run the exact same checks.
abstract final class ContentValidator {
  /// [eraFiles] maps each era's filename (e.g. `"au-lac.json"`) to its raw
  /// JSON text. [indexJson] is optional — omit it to skip the
  /// listed-vs-on-disk cross-check (the CMS validates one era at a time and
  /// doesn't necessarily have the whole set loaded).
  static ContentValidationResult validateAll({
    required String eraSchemaJson,
    required String peopleSchemaJson,
    required String periodSchemaJson,
    required Map<String, String> eraFiles,
    required String peopleJson,
    required String periodsJson,
    String? indexJson,
    String? eventSchemaJson,
    String? eventsJson,
  }) {
    final lines = <String>[];
    final issues = <ContentIssue>[];

    final eraSchema = JsonSchema.create(
      jsonDecode(eraSchemaJson) as Object,
      schemaVersion: SchemaVersion.draft2020_12,
    );
    final peopleSchema = JsonSchema.create(
      jsonDecode(peopleSchemaJson) as Object,
      schemaVersion: SchemaVersion.draft2020_12,
    );
    final periodSchema = JsonSchema.create(
      jsonDecode(periodSchemaJson) as Object,
      schemaVersion: SchemaVersion.draft2020_12,
    );

    // The people registry: validate it and collect the ids eras may reference.
    final peopleIds = <String>{};
    final peopleData = jsonDecode(peopleJson);
    final peopleResult = peopleSchema.validate(peopleData);
    if (!peopleResult.isValid) {
      lines.add('✗ people.json');
      for (final error in peopleResult.errors) {
        lines.add('    ${error.instancePath}: ${error.message}');
        issues.add(ContentIssue('people.json', error.message));
      }
    } else {
      for (final p in (peopleData as Map<String, dynamic>)['people'] as List) {
        peopleIds.add((p as Map<String, dynamic>)['id'] as String);
      }
      lines.add('✓ people.json (${peopleIds.length} people)');
    }

    // The period registry: validate it and collect the ids eras may reference.
    final periodIds = <String>{};
    final periodsData = jsonDecode(periodsJson);
    final periodsResult = periodSchema.validate(periodsData);
    if (!periodsResult.isValid) {
      lines.add('✗ periods.json');
      for (final error in periodsResult.errors) {
        lines.add('    ${error.instancePath}: ${error.message}');
        issues.add(ContentIssue('periods.json', error.message));
      }
    } else {
      for (final p in (periodsData as Map<String, dynamic>)['periods'] as List) {
        periodIds.add((p as Map<String, dynamic>)['id'] as String);
      }
      lines.add('✓ periods.json (${periodIds.length} periods)');
    }

    // The event registry (optional): validate it, then index its events.
    Map<String, Map<String, dynamic>>? eventsById;
    if (eventsJson != null) {
      final eventSchema = JsonSchema.create(
        jsonDecode(eventSchemaJson!) as Object,
        schemaVersion: SchemaVersion.draft2020_12,
      );
      final eventsData = jsonDecode(eventsJson);
      final eventsResult = eventSchema.validate(eventsData);
      if (!eventsResult.isValid) {
        lines.add('✗ events.json');
        for (final error in eventsResult.errors) {
          lines.add('    ${error.instancePath}: ${error.message}');
          issues.add(ContentIssue('events.json', error.message));
        }
      } else {
        try {
          eventsById = eventJsonById(eventsData as Map<String, dynamic>);
        } on ContentFormatException catch (e) {
          lines.add('✗ events.json');
          lines.add('    ${e.message}');
          issues.add(ContentIssue('events.json', e.message));
        }
      }
    }

    // Every event id anywhere — the registry plus events inlined in an era —
    // so `relatedEventIds` can point across eras and at standalone events.
    final allEventIds = <String>{...?eventsById?.keys};
    final inlineEventIds = <String>{};
    for (final name in eraFiles.keys) {
      final data = jsonDecode(eraFiles[name]!);
      if (data is! Map<String, dynamic>) continue;
      for (final e in (data['events'] as List? ?? const <dynamic>[])) {
        if (e is Map<String, dynamic> && e['id'] is String) {
          allEventIds.add(e['id'] as String);
          inlineEventIds.add(e['id'] as String);
        }
      }
    }
    // Ids the eras list (by ref or inline), and every roster's people — the
    // standalone checks below need both once the era loop has run.
    final listedEventIds = <String>{};
    final rosterPeople = <String>{};
    // Which era file listed each registry event first — an event belongs to
    // at most one era.
    final refOwner = <String, String>{};

    final slugsOnDisk = <String>{};
    // Event ids are public (app links, quiz questions, analytics) and must
    // be unique across the whole chronicle, not just within one era — this
    // map is filled era by era below and used to catch a collision the
    // moment the second era with the offending id is checked.
    final eventIdOwner = <String, String>{};
    final sortedNames = eraFiles.keys.toList()..sort();
    for (final name in sortedNames) {
      final data = jsonDecode(eraFiles[name]!);
      final result = eraSchema.validate(data);

      if (!result.isValid) {
        lines.add('✗ $name');
        for (final error in result.errors) {
          lines.add('    ${error.instancePath}: ${error.message}');
          issues.add(ContentIssue(name, error.message));
        }
        continue;
      }

      // Filename must match the declared slug.
      final eraMap = data as Map<String, dynamic>;
      final slug = eraMap['slug'];
      final expected = name.replaceAll('.json', '');
      if (slug != expected) {
        lines.add('✗ $name: slug "$slug" != filename "$expected"');
        issues.add(ContentIssue(name, 'slug "$slug" != filename "$expected"'));
        continue;
      }

      // Resolve `{ref}` event items against the registry; everything below
      // sees full events with an `order`, exactly as a pack or a pre-registry
      // era file would carry them.
      var eraForEvents = eraMap;
      final rawEvents = eraMap['events'] as List? ?? const <dynamic>[];
      // Listed even if this era fails below, so its events aren't then
      // misreported as standalone.
      for (final item in rawEvents) {
        if (item is! Map<String, dynamic>) continue;
        final id = isEventRef(item) ? item['ref'] : item['id'];
        if (id is String) listedEventIds.add(id);
      }
      if (rawEvents.any(isEventRef)) {
        final refIds = <String>[
          for (final item in rawEvents)
            if (isEventRef(item)) (item as Map<String, dynamic>)['ref'] as String,
        ];
        final dup = <String>{
          for (final id in refIds)
            if (refIds.where((x) => x == id).length > 1) id,
        };
        if (eventsById == null) {
          const msg = 'lists event refs but events.json is missing or invalid';
          lines.add('✗ $name (events)');
          lines.add('    $msg');
          issues.add(ContentIssue(name, msg));
          continue;
        }
        final taken = <String>[
          for (final id in refIds)
            if (refOwner[id] != null && refOwner[id] != name)
              'event id "$id" also used in ${refOwner[id]}',
        ];
        if (taken.isNotEmpty) {
          lines.add('✗ $name (events)');
          for (final msg in taken) {
            lines.add('    $msg');
            issues.add(ContentIssue(name, msg));
          }
          continue;
        }
        for (final id in refIds) {
          refOwner.putIfAbsent(id, () => name);
        }
        if (dup.isNotEmpty) {
          final msg = 'lists event(s) more than once: ${dup.join(', ')}';
          lines.add('✗ $name (events)');
          lines.add('    $msg');
          issues.add(ContentIssue(name, msg));
          continue;
        }
        try {
          eraForEvents = inlineEraEvents(eraMap, eventsById);
        } on ContentFormatException catch (e) {
          lines.add('✗ $name (events)');
          lines.add('    ${e.message}');
          issues.add(ContentIssue(name, e.message));
          continue;
        }
      }

      // Referential integrity: character refs must exist in the registry,
      // and event figureIds must be part of this era's roster.
      final refs = <String>{
        for (final c in (eraMap['characters'] as List? ?? const <dynamic>[]))
          (c as Map<String, dynamic>)['ref'] as String,
      };
      rosterPeople.addAll(refs);
      final badRefs = refs.difference(peopleIds);
      final badFigures = <String>{};
      for (final e in (eraForEvents['events'] as List? ?? const <dynamic>[])) {
        for (final fid in ((e as Map<String, dynamic>)['figureIds'] as List? ??
            const <dynamic>[])) {
          if (!refs.contains(fid)) badFigures.add(fid as String);
        }
      }
      // Referential integrity: the era's period must exist in the registry.
      final period = eraMap['period'];
      final badPeriod = period is String && !periodIds.contains(period);
      if (badRefs.isNotEmpty || badFigures.isNotEmpty || badPeriod) {
        lines.add('✗ $name (references)');
        if (badRefs.isNotEmpty) {
          final msg = 'unknown person ref(s): ${badRefs.join(', ')}';
          lines.add('    $msg');
          issues.add(ContentIssue(name, msg));
        }
        if (badFigures.isNotEmpty) {
          final msg = 'figureId(s) not in roster: ${badFigures.join(', ')}';
          lines.add('    $msg');
          issues.add(ContentIssue(name, msg));
        }
        if (badPeriod) {
          final msg = 'unknown period: $period';
          lines.add('    $msg');
          issues.add(ContentIssue(name, msg));
        }
        continue;
      }

      // Event integrity: id == slug (when a slug is given), ids unique
      // across the whole chronicle, order is a contiguous 0..n-1 run, and
      // relatedEventIds resolve to an event anywhere (this era, another era,
      // or a standalone event) and never self-reference. The schema alone can
      // express none of this.
      final events = (eraForEvents['events'] as List? ?? const <dynamic>[])
          .cast<Map<String, dynamic>>();
      final eventErrors = <String>[];
      final orders = <int>[];
      for (final e in events) {
        final id = e['id'] as String;
        final eSlug = e['slug'];
        if (eSlug is String && eSlug != id) {
          eventErrors.add('event "$id": slug "$eSlug" != id "$id"');
        }
        if (eventsById != null &&
            eventsById.containsKey(id) &&
            inlineEventIds.contains(id) &&
            !rawEvents.any((i) => isEventRef(i) && (i as Map)['ref'] == id)) {
          eventErrors.add('event "$id" is inlined here and also defined in events.json');
        }
        listedEventIds.add(id);
        final owner = eventIdOwner[id];
        if (owner != null && owner != name) {
          eventErrors.add('event id "$id" also used in $owner');
        } else {
          eventIdOwner[id] = name;
        }
        orders.add(e['order'] as int);
        for (final rel in (e['relatedEventIds'] as List? ?? const <dynamic>[])) {
          if (rel == id) {
            eventErrors.add('event "$id": relatedEventIds references itself');
          } else if (!allEventIds.contains(rel)) {
            eventErrors.add('event "$id": relatedEventIds has unknown event "$rel"');
          }
        }
      }
      final sortedOrders = [...orders]..sort();
      if (sortedOrders.asMap().entries.any((e) => e.value != e.key)) {
        eventErrors.add(
            'events\' order is not a contiguous 0..${events.length - 1} run: $sortedOrders');
      }
      if (eventErrors.isNotEmpty) {
        lines.add('✗ $name (events)');
        for (final msg in eventErrors) {
          lines.add('    $msg');
          issues.add(ContentIssue(name, msg));
        }
        continue;
      }

      slugsOnDisk.add(slug as String);
      lines.add('✓ $name');
    }

    // Standalone events (in the registry, listed by no era): the rules that
    // an era's own context would otherwise supply.
    var standaloneCount = 0;
    if (eventsById != null) {
      for (final entry in eventsById.entries) {
        if (listedEventIds.contains(entry.key)) continue;
        standaloneCount++;
        final e = entry.value;
        final problems = <String>[];
        final slug = e['slug'];
        if (slug is String && slug != entry.key) {
          problems.add('slug "$slug" != id "${entry.key}"');
        }
        final year = e['year'];
        if (year is! Map || year['value'] is! int) {
          problems.add('needs a dated year (year.value)');
        }
        if (e['hero'] == null) problems.add('needs a hero image');
        // Any registry person will do: a person on no roster is standalone
        // and has a page of their own (Cycle R).
        final unknownFigures = <String>{
          for (final f in (e['figureIds'] as List? ?? const <dynamic>[]))
            if (!peopleIds.contains(f)) f as String,
        };
        if (unknownFigures.isNotEmpty) {
          problems.add(
              'figureId(s) not in people.json: ${unknownFigures.join(', ')}');
        }
        for (final rel in (e['relatedEventIds'] as List? ?? const <dynamic>[])) {
          if (rel == entry.key) {
            problems.add('relatedEventIds references itself');
          } else if (!allEventIds.contains(rel)) {
            problems.add('relatedEventIds has unknown event "$rel"');
          }
        }
        if (problems.isNotEmpty) {
          lines.add('✗ events.json: standalone event "${entry.key}"');
          for (final msg in problems) {
            lines.add('    $msg');
            issues.add(ContentIssue('events.json', 'event "${entry.key}": $msg'));
          }
        }
      }
      if (!issues.any((i) => i.file == 'events.json')) {
        lines.add(
            '✓ events.json (${eventsById.length} events, $standaloneCount standalone)');
      }
    }

    // Standalone people (in the registry, on no era roster): with no era to
    // lend them art or context, they need both images (real or held).
    var standalonePeople = 0;
    if (peopleData is Map<String, dynamic> && peopleResult.isValid) {
      for (final p in peopleData['people'] as List) {
        final person = p as Map<String, dynamic>;
        final id = person['id'] as String;
        if (rosterPeople.contains(id)) continue;
        standalonePeople++;
        final missing = <String>[
          if (person['avatar'] == null) 'avatar',
          if (person['fullBody'] == null) 'fullBody',
        ];
        if (missing.isNotEmpty) {
          final msg =
              'standalone person "$id" needs ${missing.join(' and ')} (real or held)';
          lines.add('✗ people.json: $msg');
          issues.add(ContentIssue('people.json', msg));
        }
      }
      if (standalonePeople > 0 && !issues.any((i) => i.file == 'people.json')) {
        lines.add('✓ people.json ($standalonePeople standalone)');
      }
    }

    // The bundled manifest must list exactly the era files present.
    if (indexJson != null) {
      final index = jsonDecode(indexJson);
      final listed = <String>{
        for (final s in (index as Map<String, dynamic>)['eras'] as List) s as String,
      };
      final missing = slugsOnDisk.difference(listed);
      final extra = listed.difference(slugsOnDisk);
      if (missing.isNotEmpty || extra.isNotEmpty) {
        lines.add('✗ content/index.json out of sync with content/eras/');
        if (missing.isNotEmpty) {
          final msg = 'not listed: ${missing.join(', ')}';
          lines.add('    $msg');
          issues.add(ContentIssue('index.json', msg));
        }
        if (extra.isNotEmpty) {
          final msg = 'listed but absent: ${extra.join(', ')}';
          lines.add('    $msg');
          issues.add(ContentIssue('index.json', msg));
        }
      } else {
        lines.add('✓ content/index.json');
      }
    }

    return ContentValidationResult(
      lines: lines,
      issues: issues,
      peopleCount: peopleIds.length,
      periodCount: periodIds.length,
      eraCount: slugsOnDisk.length,
      eventCount: eventsById?.length ?? 0,
      standaloneEventCount: standaloneCount,
    );
  }
}
