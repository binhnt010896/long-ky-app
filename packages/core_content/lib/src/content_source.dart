import 'dart:convert';

import 'package:core_domain/core_domain.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// Raised when a content source cannot supply what was asked of it.
class ContentSourceException implements Exception {
  ContentSourceException(this.message);
  final String message;
  @override
  String toString() => 'ContentSourceException: $message';
}

/// Where era JSON comes from. Deliberately narrow so the runtime (bundled
/// assets), tests (disk/in-memory), and a future OTA layer are interchangeable.
abstract interface class ContentSource {
  /// Slugs this source can currently serve, in no particular order.
  Future<List<String>> availableSlugs();

  /// Raw JSON text for one era, by slug. Throws [ContentSourceException] if the
  /// slug is unknown to this source.
  Future<String> loadEraJson(String slug);

  /// Raw JSON text for the people registry (`content/people.json`) — the single
  /// source of figure identity that eras reference. Throws
  /// [ContentSourceException] if it cannot be found.
  Future<String> loadPeopleJson();

  /// Raw JSON text for the period registry (`content/periods.json`) — the
  /// ordered dynasties/periods that eras group under. Throws
  /// [ContentSourceException] if it cannot be found.
  Future<String> loadPeriodsJson();

  /// Raw JSON text of the *standalone* events — events no era lists
  /// (Cycle N) — as `{"schemaVersion": 1, "events": [...]}`. Every other event
  /// arrives inlined inside its era's JSON, exactly as it always has, so a
  /// source never hands out `{ref}` items. Throws [ContentSourceException] if
  /// this source has no say on standalone events (a pack built before they
  /// existed), so the next tier answers instead.
  Future<String> loadStandaloneEventsJson();
}

/// Reads content shipped inside the app bundle.
///
/// Expects a manifest asset listing the available era slugs and one JSON file
/// per era. The app's pubspec must declare these under `flutter/assets`.
///
/// Eras on disk list their events as `{ref}` items into `events.json`;
/// [loadEraJson] inlines them (with `order` = list position), so what leaves
/// this class is the same full-event shape a content pack carries.
///
/// Manifest shape (`content/index.json`):
/// ```json
/// { "schemaVersion": 1, "eras": ["hong-bang-van-lang"] }
/// ```
class BundledContentSource implements ContentSource {
  BundledContentSource({
    AssetBundle? bundle,
    this.manifestPath = 'content/index.json',
    this.eraDir = 'content/eras',
    this.peoplePath = 'content/people.json',
    this.periodsPath = 'content/periods.json',
    this.eventsPath = 'content/events.json',
  }) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final String manifestPath;
  final String eraDir;
  final String peoplePath;
  final String periodsPath;
  final String eventsPath;

  Map<String, Map<String, dynamic>>? _eventsById;
  List<String>? _standaloneIds;

  @override
  Future<List<String>> availableSlugs() async {
    final String raw;
    try {
      raw = await _bundle.loadString(manifestPath);
    } catch (_) {
      throw ContentSourceException('content manifest not found: $manifestPath');
    }
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic> || json['eras'] is! List) {
      throw ContentSourceException('malformed content manifest: $manifestPath');
    }
    return <String>[
      for (final s in json['eras'] as List)
        if (s is String) s,
    ];
  }

  Future<Map<String, Map<String, dynamic>>> _events() async {
    final cached = _eventsById;
    if (cached != null) return cached;
    final String raw;
    try {
      raw = await _bundle.loadString(eventsPath);
    } catch (_) {
      throw ContentSourceException('events asset not found: $eventsPath');
    }
    try {
      return _eventsById =
          eventJsonById(jsonDecode(raw) as Map<String, dynamic>);
    } on ContentFormatException catch (e) {
      throw ContentSourceException('malformed events asset: ${e.message}');
    }
  }

  Future<String> _rawEra(String slug) async {
    final path = '$eraDir/$slug.json';
    try {
      return await _bundle.loadString(path);
    } catch (_) {
      throw ContentSourceException('era asset not found: $path');
    }
  }

  @override
  Future<String> loadEraJson(String slug) async {
    final raw = await _rawEra(slug);
    final decoded = jsonDecode(raw);
    // Only touch events.json when this era actually lists refs, so a bundle
    // of already-inlined eras (a fixture) needs no registry at all.
    if (decoded is! Map<String, dynamic> ||
        !((decoded['events'] as List?) ?? const <dynamic>[]).any(isEventRef)) {
      return raw;
    }
    try {
      return jsonEncode(inlineEraEvents(decoded, await _events()));
    } on ContentFormatException catch (e) {
      throw ContentSourceException('era `$slug`: ${e.message}');
    }
  }

  @override
  Future<String> loadStandaloneEventsJson() async {
    final Map<String, Map<String, dynamic>> all;
    try {
      all = await _events();
    } on ContentSourceException {
      // No registry in this bundle → no standalone events, and that is a
      // definite answer for the shipped baseline.
      return jsonEncode(<String, dynamic>{'schemaVersion': 1, 'events': <dynamic>[]});
    }
    var ids = _standaloneIds;
    if (ids == null) {
      final eras = <Map<String, dynamic>>[];
      for (final slug in await availableSlugs()) {
        eras.add(jsonDecode(await _rawEra(slug)) as Map<String, dynamic>);
      }
      ids = _standaloneIds = standaloneEventIds(eras, all.keys);
    }
    return jsonEncode(<String, dynamic>{
      'schemaVersion': 1,
      'events': [for (final id in ids) all[id]],
    });
  }

  @override
  Future<String> loadPeopleJson() async {
    try {
      return await _bundle.loadString(peoplePath);
    } catch (_) {
      throw ContentSourceException('people asset not found: $peoplePath');
    }
  }

  @override
  Future<String> loadPeriodsJson() async {
    try {
      return await _bundle.loadString(periodsPath);
    } catch (_) {
      throw ContentSourceException('periods asset not found: $periodsPath');
    }
  }
}
