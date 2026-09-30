import 'dart:convert';

import 'package:core_domain/core_domain.dart';

import 'content_source.dart';
import 'ota_content_source.dart';

/// Loads and caches [Era]s from a [ContentSource].
///
/// This is the one place the app asks for content. It decodes JSON, parses into
/// [Era] models (which enforce the shape and surface [ContentFormatException]),
/// verifies the slug matches, and memoises results. Swapping bundled → OTA is a
/// matter of the [ContentSource] passed in; callers here don't change.
class ContentRepository {
  ContentRepository(this.source);

  /// Convenience constructor for the standard app wiring: bundled assets behind
  /// the OTA seam.
  ContentRepository.withOta(ContentSource bundled)
      : source = OtaContentSource(bundled: bundled);

  final ContentSource source;

  final Map<String, Era> _cache = <String, Era>{};
  PeopleRegistry? _people;
  PeriodRegistry? _periods;
  List<HistoryEvent>? _standalone;

  /// Load and cache the people registry (`content/people.json`).
  Future<PeopleRegistry> _loadPeople() async {
    final cached = _people;
    if (cached != null) return cached;
    final raw = await source.loadPeopleJson();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw ContentFormatException('people JSON is not an object',
          path: 'people');
    }
    return _people = PeopleRegistry.fromJson(decoded);
  }

  /// Load and cache the period registry (`content/periods.json`).
  Future<PeriodRegistry> loadPeriods() async {
    final cached = _periods;
    if (cached != null) return cached;
    final raw = await source.loadPeriodsJson();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw ContentFormatException('periods JSON is not an object',
          path: 'periods');
    }
    return _periods = PeriodRegistry.fromJson(decoded);
  }

  /// Every non-empty dynasty in order, each paired with its eras (sorted by
  /// [Era.order]). Drives the dynasty hub: periods scroll vertically, the eras
  /// within each scroll horizontally. Periods with no eras yet are omitted.
  Future<List<Dynasty>> loadDynasties() async {
    final periods = await loadPeriods();
    final eras = await loadAllEras();
    final byPeriod = <String, List<Era>>{};
    for (final era in eras) {
      final pid = era.period;
      if (pid == null) continue;
      (byPeriod[pid] ??= <Era>[]).add(era);
    }
    return <Dynasty>[
      for (final p in periods.ordered)
        if (byPeriod[p.id] case final es? when es.isNotEmpty)
          Dynasty(period: p, eras: List<Era>.unmodifiable(es)),
    ];
  }

  /// Load one era by slug. Cached after first read.
  Future<Era> loadEra(String slug) async {
    final cached = _cache[slug];
    if (cached != null) return cached;

    final people = await _loadPeople();
    final raw = await source.loadEraJson(slug);
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw ContentFormatException('era JSON is not an object', path: slug);
    }
    final era = Era.fromJson(decoded, people);
    if (era.slug != slug) {
      throw ContentFormatException(
        'slug mismatch: file `$slug` declares `${era.slug}`',
        path: slug,
      );
    }
    _cache[slug] = era;
    return era;
  }

  /// Load every available era, sorted by [Era.order].
  Future<List<Era>> loadAllEras() async {
    final slugs = await source.availableSlugs();
    final eras = <Era>[];
    for (final slug in slugs) {
      eras.add(await loadEra(slug));
    }
    eras.sort((a, b) => a.order.compareTo(b.order));
    return List<Era>.unmodifiable(eras);
  }

  /// The standalone events — events no era lists — in source order. Cached.
  Future<List<HistoryEvent>> loadStandaloneEvents() async {
    final cached = _standalone;
    if (cached != null) return cached;
    final decoded = jsonDecode(await source.loadStandaloneEventsJson());
    if (decoded is! Map<String, dynamic>) {
      throw ContentFormatException('standalone events JSON is not an object',
          path: 'standaloneEvents');
    }
    return _standalone =
        List<HistoryEvent>.unmodifiable(EventRegistry.fromJson(decoded).events);
  }

  /// Finds the event with [id], wherever it lives: inside an era (returned
  /// with that era) or standalone (era null). Null if there is no such event.
  Future<EventLocation?> findEvent(String id) async {
    for (final era in await loadAllEras()) {
      for (final e in era.events) {
        if (e.id == id) return EventLocation(e, era);
      }
    }
    for (final e in await loadStandaloneEvents()) {
      if (e.id == id) return EventLocation(e, null);
    }
    return null;
  }

  /// Drop cached eras and people (e.g. after an OTA [OtaContentSource.sync]).
  void invalidate() {
    _cache.clear();
    _people = null;
    _periods = null;
    _standalone = null;
  }
}

/// An event and the era that contains it — null for a standalone event.
class EventLocation {
  const EventLocation(this.event, this.era);

  final HistoryEvent event;
  final Era? era;

  bool get isStandalone => era == null;
}
