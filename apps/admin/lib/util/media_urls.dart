import 'dart:convert';

/// The public CDN Long Ký serves converted media from — same bucket
/// `apps/mobile/lib/theme/content_assets.dart` points at by default.
const cdnMediaBase = 'https://pub-3e1d5dacc331435e8651e740cd635e56.r2.dev/media';

/// Sources are always PNG/JPG or `.mp4` (see .gitignore's media list) —
/// extension alone is enough to tell a video slot from an image one.
bool isVideoPath(String path) => path.toLowerCase().endsWith('.mp4');

/// `content/media-manifest.json` (schema v2): source path → `{key, v}` for
/// the published, cache-busted WebP. A path with no entry here has never
/// been published — [[event-count-follows-source]]'s sibling bug, the
/// missing Hai Bà Trưng art, was exactly a path with no manifest entry.
class MediaManifest {
  MediaManifest(this._files);

  factory MediaManifest.fromJson(String json) {
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return MediaManifest((decoded['files'] as Map<String, dynamic>).cast<String, dynamic>());
  }

  final Map<String, dynamic> _files;

  bool isPublished(String sourcePath) => _files.containsKey(sourcePath);

  /// The CDN URL for [sourcePath], or null if it's never been published.
  String? urlFor(String sourcePath) {
    final entry = _files[sourcePath] as Map<String, dynamic>?;
    if (entry == null) return null;
    final key = entry['key'] as String;
    final v = entry['v'] as String;
    return '$cdnMediaBase/$key?v=$v';
  }
}
