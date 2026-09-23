import 'dart:convert';
import 'dart:io';

import 'package:core_content/core_content.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../theme/content_assets.dart';

/// Where the app checks for a newer content pack (era text, people, periods
/// and their media manifest, all in one file) — see `tool/publish_content.sh`.
String get kContentLatestUrl => '$kContentMediaBase/content/latest.json';

/// The content version currently active: the bundled baseline until a newer
/// downloaded pack is adopted, either during the splash or at the next launch.
final activeContentVersionProvider = StateProvider<int>((ref) => 0);

/// Fetches, validates, persists and — at startup — resumes a downloaded
/// content pack, layered over the bundled content via [OtaContentSource].
/// Every method here is safe to call blind: a bad network, a corrupt store,
/// a bad hash or a pack that fails to parse all fall back to "keep whatever
/// is currently active," never a crash and never partially-applied content.
class ContentSync {
  ContentSync._();

  static Future<int> bundledVersion() async {
    try {
      final raw = await rootBundle
          .loadString('assets/content/content-version.json');
      final json = jsonDecode(raw);
      if (json is Map<String, dynamic> && json['version'] is int) {
        return json['version'] as int;
      }
    } catch (_) {
      // No committed baseline yet (or a malformed one) — 0 means any real
      // downloaded pack is newer, which is the safe direction to fail in.
    }
    return 0;
  }

  /// The on-device store for a downloaded pack. Null on web, which keeps a
  /// pack in memory for the session only — there's no meaningful persistent
  /// app-private storage to write it to, and the CDN is one request away.
  static Future<File?> _storeFile() async {
    if (kIsWeb) return null;
    final dir = await getApplicationSupportDirectory();
    final contentDir = Directory('${dir.path}/content');
    if (!contentDir.existsSync()) contentDir.createSync(recursive: true);
    return File('${contentDir.path}/pack.json');
  }

  /// Builds the app's startup content source: the bundle, with a
  /// previously-downloaded pack layered on top as [OtaContentSource.overlay]
  /// if one is on disk, still valid, and newer than the bundled baseline.
  static Future<({OtaContentSource source, int activeVersion})> startup(
    BundledContentSource bundled,
  ) async {
    final ota = OtaContentSource(bundled: bundled);
    final bundledVersionValue = await bundledVersion();
    var activeVersion = bundledVersionValue;

    final file = await _storeFile();
    if (file != null && file.existsSync()) {
      try {
        final pack = ContentPack.parseAndValidate(await file.readAsString());
        if (pack.version > bundledVersionValue) {
          ota.overlay = PackContentSource(pack);
          ContentMedia.applyManifest(pack.media);
          activeVersion = pack.version;
        }
      } catch (_) {
        // A stored pack that no longer validates (corrupted, or this app
        // build no longer understands its schemaVersion) is discarded —
        // startup proceeds on the bundle.
        try {
          await file.delete();
        } catch (_) {
          // Deletion failing is not worth blocking startup over.
        }
      }
    }
    return (source: ota, activeVersion: activeVersion);
  }

  /// Checks `latest.json`, and if it names a pack newer than [activeVersion],
  /// downloads it, verifies its sha256, validates it, persists it to disk,
  /// and returns it. Returns null on anything short of a fully verified pack
  /// — a slow/offline network, a stale pointer, a hash mismatch, or content
  /// that fails to parse.
  static Future<ContentPack?> checkForUpdate(int activeVersion) async {
    try {
      final latestRes = await http
          .get(Uri.parse(kContentLatestUrl))
          .timeout(const Duration(seconds: 2));
      if (latestRes.statusCode != 200) return null;
      final latest = jsonDecode(latestRes.body);
      if (latest is! Map<String, dynamic>) return null;

      final schemaVersion = latest['schemaVersion'];
      final version = latest['version'];
      final sha256Hex = latest['sha256'];
      final path = latest['path'];
      if (schemaVersion is! int || schemaVersion > kSupportedPackSchema) {
        return null;
      }
      if (version is! int || version <= activeVersion) return null;
      if (sha256Hex is! String || path is! String) return null;

      final packRes = await http
          .get(Uri.parse('$kContentMediaBase/$path'))
          .timeout(const Duration(seconds: 20));
      if (packRes.statusCode != 200) return null;

      final raw = packRes.body;
      final actualHash = sha256.convert(utf8.encode(raw)).toString();
      if (actualHash != sha256Hex) return null;

      final pack = ContentPack.parseAndValidate(raw);

      final file = await _storeFile();
      if (file != null) {
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsString(raw);
        await tmp.rename(file.path);
      }
      return pack;
    } catch (_) {
      return null;
    }
  }
}
