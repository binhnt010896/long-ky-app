import 'dart:convert';

import 'package:core_domain/core_domain.dart';

import 'content_source.dart';

/// The newest content-pack schema this app build understands. A downloaded
/// pack whose `schemaVersion` exceeds this is rejected outright — an old app
/// must never try to parse a future format it doesn't know about.
const int kSupportedPackSchema = 1;

/// A single downloaded snapshot of all remote content — the index, people,
/// periods and media manifests, and every era's JSON — built and published by
/// `tool/build_content_pack.dart` as one file per version plus a `latest.json`
/// pointer. One file means a phone can never end up with eras from two
/// different publishes mixed together.
class ContentPack {
  const ContentPack({
    required this.schemaVersion,
    required this.version,
    required this.index,
    required this.people,
    required this.periods,
    required this.media,
    required this.eras,
    this.standaloneEvents,
    this.streets,
  });

  final int schemaVersion;

  /// Publish timestamp as `yyyyMMddHHmmss`, e.g. `20260923153000`. Strictly
  /// increasing across publishes; the app only ever adopts a pack whose
  /// version is newer than what it's already running.
  final int version;

  final Map<String, dynamic> index;
  final Map<String, dynamic> people;
  final Map<String, dynamic> periods;
  final Map<String, dynamic> media;

  /// Every era's raw JSON, keyed by slug — events always inlined with their
  /// `order`, exactly the shape every app build has parsed since day one.
  final Map<String, Map<String, dynamic>> eras;

  /// Events no era lists (Cycle N), as `{schemaVersion, events}`. Absent from
  /// a pack built before they existed, and ignored by an app build that
  /// predates them — which is why adding it needed no `schemaVersion` bump.
  final Map<String, dynamic>? standaloneEvents;

  /// Street mappings by city (`{"hcm": <content/streets/hcm.json>}`), so a new
  /// street or a re-pointed one reaches phones without an app release. Absent
  /// from a pack built before this existed, and ignored by an app build that
  /// predates it — additive, like [standaloneEvents], so no `schemaVersion` bump.
  final Map<String, dynamic>? streets;

  /// Parses and fully validates a pack downloaded as raw JSON text — every
  /// check that would let a phone actually render this content, not just
  /// well-formed JSON. Throws [ContentSourceException] describing the first
  /// problem found; the caller (content-sync) treats that as "reject this
  /// pack, keep what's currently active."
  static ContentPack parseAndValidate(String raw) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (e) {
      throw ContentSourceException('content pack is not valid JSON: $e');
    }
    if (decoded is! Map<String, dynamic>) {
      throw ContentSourceException('content pack is not a JSON object');
    }

    final schemaVersion = decoded['schemaVersion'];
    if (schemaVersion is! int) {
      throw ContentSourceException('content pack missing schemaVersion');
    }
    if (schemaVersion > kSupportedPackSchema) {
      throw ContentSourceException(
          'content pack schemaVersion $schemaVersion is newer than this app supports ($kSupportedPackSchema)');
    }

    final version = decoded['version'];
    if (version is! int) {
      throw ContentSourceException('content pack missing version');
    }

    final index = decoded['index'];
    final people = decoded['people'];
    final periods = decoded['periods'];
    final media = decoded['media'];
    final erasRaw = decoded['eras'];
    if (index is! Map<String, dynamic> ||
        people is! Map<String, dynamic> ||
        periods is! Map<String, dynamic> ||
        media is! Map<String, dynamic> ||
        erasRaw is! Map<String, dynamic>) {
      throw ContentSourceException(
          'content pack missing index/people/periods/media/eras');
    }

    // Every slug the index lists must have a matching era entry.
    final slugs = index['eras'];
    if (slugs is! List) {
      throw ContentSourceException('content pack index.eras is not a list');
    }
    for (final s in slugs) {
      if (s is! String || !erasRaw.containsKey(s)) {
        throw ContentSourceException(
            'content pack index lists era `$s` with no matching entry');
      }
    }

    // Every registry and every era must actually parse against the domain
    // models — the same parsers the bundled content goes through, so a pack
    // that "looks like JSON" but fails a real parse is rejected up front
    // rather than crashing a screen later.
    PeopleRegistry peopleRegistry;
    try {
      peopleRegistry = PeopleRegistry.fromJson(people);
    } catch (e) {
      throw ContentSourceException('content pack people.json is invalid: $e');
    }
    try {
      PeriodRegistry.fromJson(periods);
    } catch (e) {
      throw ContentSourceException(
          'content pack periods.json is invalid: $e');
    }

    final eras = <String, Map<String, dynamic>>{};
    for (final entry in erasRaw.entries) {
      final eraJson = entry.value;
      if (eraJson is! Map<String, dynamic>) {
        throw ContentSourceException(
            'content pack era `${entry.key}` is not an object');
      }
      try {
        Era.fromJson(eraJson, peopleRegistry);
      } catch (e) {
        throw ContentSourceException(
            'content pack era `${entry.key}` failed to parse: $e');
      }
      eras[entry.key] = eraJson;
    }

    final standalone = decoded['standaloneEvents'];
    if (standalone != null) {
      if (standalone is! Map<String, dynamic>) {
        throw ContentSourceException(
            'content pack standaloneEvents is not an object');
      }
      try {
        EventRegistry.fromJson(standalone);
      } catch (e) {
        throw ContentSourceException(
            'content pack standaloneEvents is invalid: $e');
      }
    }

    final streets = decoded['streets'];
    if (streets != null) {
      if (streets is! Map<String, dynamic>) {
        throw ContentSourceException('content pack streets is not an object');
      }
      final standaloneIds = <String>{
        if (standalone is Map<String, dynamic>)
          for (final e in EventRegistry.fromJson(standalone).events) e.id,
      };
      for (final entry in streets.entries) {
        final file = entry.value;
        if (file is! Map<String, dynamic>) {
          throw ContentSourceException(
              'content pack streets `${entry.key}` is not an object');
        }
        // The same referential rules tool/validate_content.dart applies, so a
        // mapping that points at a person or event this pack does not carry
        // is rejected here rather than opening a dead card on a phone.
        final problems = StreetMapValidator.validate(
          streetsJson: jsonEncode(file),
          peopleIds: peopleRegistry.byId.keys.toSet(),
          eras: eras.values.toList(),
          standaloneEventIds: standaloneIds,
          periodIds: {
            for (final p in (periods['periods'] as List? ?? const <dynamic>[]))
              if (p is Map<String, dynamic>) p['id'] as String,
          },
        );
        if (problems.isNotEmpty) {
          throw ContentSourceException(
              'content pack streets `${entry.key}` is invalid: ${problems.first}');
        }
      }
    }

    return ContentPack(
      schemaVersion: schemaVersion,
      version: version,
      index: index,
      people: people,
      periods: periods,
      media: media,
      eras: eras,
      standaloneEvents: standalone as Map<String, dynamic>?,
      streets: streets as Map<String, dynamic>?,
    );
  }
}

/// Serves content from a validated [ContentPack] over the same [ContentSource]
/// interface as the bundled assets, so [OtaContentSource] can prefer it as an
/// overlay without the rest of the app knowing the difference.
class PackContentSource implements ContentSource, StreetsSource {
  PackContentSource(this.pack);

  final ContentPack pack;

  @override
  Future<List<String>> availableSlugs() async =>
      List<String>.unmodifiable(pack.eras.keys);

  @override
  Future<String> loadEraJson(String slug) async {
    final era = pack.eras[slug];
    if (era == null) {
      throw ContentSourceException('era not in content pack: $slug');
    }
    return jsonEncode(era);
  }

  @override
  Future<String> loadPeopleJson() async => jsonEncode(pack.people);

  @override
  Future<String> loadPeriodsJson() async => jsonEncode(pack.periods);

  @override
  Future<String> loadStandaloneEventsJson() async {
    final standalone = pack.standaloneEvents;
    // A pack with no word on standalone events (built before they existed)
    // must not answer "none" over a bundle that has some — defer instead.
    if (standalone == null) {
      throw ContentSourceException('content pack predates standalone events');
    }
    return jsonEncode(standalone);
  }

  @override
  Future<String?> loadStreetsJson(String city) async {
    final file = pack.streets?[city];
    return file == null ? null : jsonEncode(file);
  }
}
