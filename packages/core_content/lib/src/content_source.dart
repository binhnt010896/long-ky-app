import 'dart:convert';

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
}

/// Reads content shipped inside the app bundle.
///
/// Expects a manifest asset listing the available era slugs and one JSON file
/// per era. The app's pubspec must declare these under `flutter/assets`.
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
  }) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final String manifestPath;
  final String eraDir;
  final String peoplePath;
  final String periodsPath;

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

  @override
  Future<String> loadEraJson(String slug) async {
    final path = '$eraDir/$slug.json';
    try {
      return await _bundle.loadString(path);
    } catch (_) {
      throw ContentSourceException('era asset not found: $path');
    }
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
