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
/// video layer) also read it to skip their own network/cache work when a
/// test has set it — not `@visibleForTesting` because of that.
ImageProvider Function(String path)? debugContentImageOverride;

/// Era media on the R2 CDN, with a shared on-device cache and cache-busting
/// versions read from the bundled `content/media-manifest.json`.
class ContentMedia {
  ContentMedia._();

  static Map<String, String> _versions = const <String, String>{};

  /// The on-device cache shared by images ([contentImageProvider]) and video
  /// ([ContentMedia.url] + `getSingleFile`, see `SceneVideoLayer`).
  static final CacheManager cache = CacheManager(
    Config(
      'longKyMedia',
      stalePeriod: const Duration(days: 365),
      maxNrOfCacheObjects: 1000,
    ),
  );

  /// Loads the media manifest's file versions from the app bundle. A missing
  /// or malformed manifest is never fatal — URLs just resolve without a
  /// `?v=` query, so they still work, just without cache-busting.
  static Future<void> load() async {
    try {
      final raw = await rootBundle.loadString('assets/content/media-manifest.json');
      final json = jsonDecode(raw);
      if (json is Map<String, dynamic> && json['files'] is Map) {
        _versions = <String, String>{
          for (final entry in (json['files'] as Map).entries)
            entry.key as String: entry.value as String,
        };
      }
    } catch (_) {
      // Leave _versions empty; every url() still resolves, just unversioned.
    }
  }

  /// Test seam: seed manifest versions directly, without a real bundle asset.
  @visibleForTesting
  static void debugSetVersions(Map<String, String> versions) {
    _versions = versions;
  }

  /// The full URL for a content-relative media path, with `?v=<hash>` when
  /// the path is present in the loaded manifest.
  static String url(String contentRelativePath) {
    final encoded = Uri.encodeFull(contentRelativePath);
    final version = _versions[contentRelativePath];
    return version == null
        ? '$kContentMediaBase/$encoded'
        : '$kContentMediaBase/$encoded?v=$version';
  }
}

/// Resolve a content-relative media path to an [ImageProvider] backed by the
/// R2 CDN and the shared on-device cache. Tests substitute
/// [debugContentImageOverride] so no widget test touches the network.
ImageProvider contentImageProvider(String contentRelativePath) {
  final override = debugContentImageOverride;
  if (override != null) return override(contentRelativePath);
  return CachedNetworkImageProvider(
    ContentMedia.url(contentRelativePath),
    cacheManager: ContentMedia.cache,
  );
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
