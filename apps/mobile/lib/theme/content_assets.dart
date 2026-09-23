import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Where era media (images, videos) is served from. JSON paths are stored
/// content-root-relative (e.g. `eras/hong-bang/scene/sky.png`) so the same
/// paths work against any base — override per build with
/// `--dart-define=CONTENT_MEDIA_BASE=https://…`. Switch the default to the
/// custom domain before launch.
const String kContentMediaBase = String.fromEnvironment(
  'CONTENT_MEDIA_BASE',
  defaultValue: 'https://pub-3e1d5dacc331435e8651e740cd635e56.r2.dev',
);

/// Overrides how a content-relative path resolves to an [ImageProvider], set
/// once by `flutter_test_config.dart` for every widget test so nothing hits
/// the network or the cache plugin. Production widgets (e.g. the era-cover
/// video layer, the media prefetcher) also read it to skip their own
/// network/cache work when a test has set it — not `@visibleForTesting`
/// because of that.
ImageProvider Function(String path)? debugContentImageOverride;

/// One media manifest entry: the served (WebP, usually) file for a source
/// path, and its cache-busting version.
class ContentMediaEntry {
  const ContentMediaEntry({required this.key, required this.v});

  /// The served path under the bucket's `media/` prefix, e.g.
  /// `eras/au-lac/cover.webp` for source `eras/au-lac/cover.png`.
  final String key;

  /// Cache-busting version: changes when the source bytes or the encoder
  /// settings change.
  final String v;
}

/// Era media on the R2 CDN, with a shared on-device cache and cache-busting
/// versions/served-keys read from the bundled `content/media-manifest.json`
/// (schema v2), or applied at runtime from a downloaded content pack's media
/// manifest (see the content-sync work).
class ContentMedia {
  ContentMedia._();

  static Map<String, ContentMediaEntry> _entries =
      const <String, ContentMediaEntry>{};

  /// The on-device cache shared by images ([contentImageProvider]), video
  /// (`SceneVideoLayer`) and the background prefetcher (`MediaPrefetcher`).
  static final CacheManager cache = CacheManager(
    Config(
      'longKyMedia',
      stalePeriod: const Duration(days: 365),
      maxNrOfCacheObjects: 1000,
    ),
  );

  /// Loads the media manifest from the app bundle. A missing or malformed
  /// manifest is never fatal — every [url] still resolves, just without a
  /// served-key remap or a `?v=` query.
  static Future<void> load() async {
    try {
      final raw =
          await rootBundle.loadString('assets/content/media-manifest.json');
      applyManifest(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Leave _entries as-is (empty on first call).
    }
  }

  /// Applies a media-manifest JSON object (schema v1 or v2) — used at startup
  /// from the bundle, and by the content-sync work when a downloaded pack
  /// becomes active.
  static void applyManifest(Map<String, dynamic> manifestJson) {
    final files = manifestJson['files'];
    if (files is! Map) return;
    final schemaVersion = manifestJson['schemaVersion'];
    final entries = <String, ContentMediaEntry>{};
    for (final entry in files.entries) {
      final path = entry.key as String;
      final value = entry.value;
      if (schemaVersion == 2 && value is Map) {
        final key = value['key'];
        final v = value['v'];
        if (key is String && v is String) {
          entries[path] = ContentMediaEntry(key: key, v: v);
        }
      } else if (value is String) {
        // Schema v1: the path itself is the served key, value is the version.
        entries[path] = ContentMediaEntry(key: path, v: value);
      }
    }
    _entries = entries;
  }

  /// Test seam: seed manifest entries directly, without a real bundle asset.
  @visibleForTesting
  static void debugSetEntries(Map<String, ContentMediaEntry> entries) {
    _entries = entries;
  }

  /// The full URL for a content-relative media path, under the bucket's
  /// `media/` prefix, with `?v=<hash>` when the path is present in the loaded
  /// manifest.
  static String url(String contentRelativePath) {
    final entry = _entries[contentRelativePath];
    if (entry == null) {
      return '$kContentMediaBase/media/${Uri.encodeFull(contentRelativePath)}';
    }
    return '$kContentMediaBase/media/${Uri.encodeFull(entry.key)}?v=${entry.v}';
  }
}

/// The pixel width to decode an image at, given its logical (dp) display
/// width — used to avoid decoding a full-resolution source for a small
/// thumbnail (e.g. a 44dp dynasty crest).
int decodeWidthFor(BuildContext context, double logicalWidth) =>
    (logicalWidth * MediaQuery.devicePixelRatioOf(context)).ceil();

/// Resolve a content-relative media path to an [ImageProvider] backed by the
/// R2 CDN and the shared on-device cache. Tests substitute
/// [debugContentImageOverride] so no widget test touches the network.
///
/// [decodeWidth], when given, decodes the image at that pixel width instead
/// of its native resolution — pass [decodeWidthFor] for a thumbnail.
ImageProvider contentImageProvider(String contentRelativePath,
    {int? decodeWidth}) {
  final override = debugContentImageOverride;
  final base = override != null
      ? override(contentRelativePath)
      : CachedNetworkImageProvider(
          ContentMedia.url(contentRelativePath),
          cacheManager: ContentMedia.cache,
        );
  return ResizeImage.resizeIfNeeded(decodeWidth, null, base);
}

/// An `Image.frameBuilder` that fades art in on first decode, so large scene
/// and hero images resolve gracefully instead of popping from black.
Widget fadeInImageFrame(
  BuildContext context,
  Widget child,
  int? frame,
  bool wasSynchronouslyLoaded,
) {
  if (wasSynchronouslyLoaded) return child;
  return AnimatedOpacity(
    opacity: frame == null ? 0 : 1,
    duration: const Duration(milliseconds: 450),
    curve: Curves.easeOut,
    child: child,
  );
}
