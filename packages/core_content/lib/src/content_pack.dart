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

  /// Every era's raw JSON, keyed by slug.
  final Map<String, Map<String, dynamic>> eras;

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

    return ContentPack(
      schemaVersion: schemaVersion,
      version: version,
      index: index,
      people: people,
      periods: periods,
      media: media,
      eras: eras,
    );
  }
}

/// Serves content from a validated [ContentPack] over the same [ContentSource]
/// interface as the bundled assets, so [OtaContentSource] can prefer it as an
/// overlay without the rest of the app knowing the difference.
class PackContentSource implements ContentSource {
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
}
