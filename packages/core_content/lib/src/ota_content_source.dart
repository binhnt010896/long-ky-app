import 'content_source.dart';

/// The seam for over-the-air content updates.
///
/// It composes a bundled fallback with an optional [overlay] source, and —
/// tried before that — an optional [liveOverlay] (Cycle K5: a live-updated
/// source such as Firestore). Reads try [liveOverlay], then [overlay], then
/// fall back to the bundle, each on [ContentSourceException], so a partial
/// or not-yet-configured live source degrades to whatever OTA pack the app
/// already has, and that in turn degrades to the shipped baseline — nothing
/// here ever throws for "the live source isn't set up yet." There is no
/// `sync()` here — the app (`apps/mobile/lib/state/content_sync.dart` for
/// the pack, `firestore_content_source.dart` for the live source) owns
/// fetching/validating/persisting and simply assigns [overlay]/[liveOverlay]
/// once ready. Keeping that outside this package means it never needs to
/// know about HTTP, the filesystem, or a specific live-source SDK.
class OtaContentSource implements ContentSource, StreetsSource {
  OtaContentSource({required this.bundled, this.overlay, this.liveOverlay});

  /// Always-present content shipped with the app.
  final ContentSource bundled;

  /// Updated content fetched at runtime, once the app has validated it. Null
  /// until then, or if validation ever fails.
  ContentSource? overlay;

  /// A live-updated source (Firestore), tried before [overlay]. Null until
  /// the app has one available — every read here catches
  /// [ContentSourceException] and falls through, so this is always safe to
  /// leave unset.
  ContentSource? liveOverlay;

  Future<T> _preferred<T>(Future<T> Function(ContentSource) read) async {
    for (final source in [liveOverlay, overlay]) {
      if (source == null) continue;
      try {
        return await read(source);
      } on ContentSourceException {
        // Fall through to the next tier.
      }
    }
    return read(bundled);
  }

  @override
  Future<List<String>> availableSlugs() async {
    final result = <String>{...await bundled.availableSlugs()};
    for (final source in [overlay, liveOverlay]) {
      if (source == null) continue;
      try {
        result.addAll(await source.availableSlugs());
      } on ContentSourceException {
        // A source that can't list its slugs right now just contributes
        // none — the other tiers still cover the rest.
      }
    }
    return result.toList();
  }

  @override
  Future<String> loadEraJson(String slug) =>
      _preferred((s) => s.loadEraJson(slug));

  @override
  Future<String> loadPeopleJson() => _preferred((s) => s.loadPeopleJson());

  @override
  Future<String> loadPeriodsJson() => _preferred((s) => s.loadPeriodsJson());

  @override
  Future<String> loadStandaloneEventsJson() =>
      _preferred((s) => s.loadStandaloneEventsJson());

  /// The newest street mapping for [city]: the live source, then the downloaded
  /// pack, else null — and the caller reads the mapping bundled in the app.
  @override
  Future<String?> loadStreetsJson(String city) async {
    for (final source in [liveOverlay, overlay]) {
      if (source is! StreetsSource) continue;
      try {
        final json = await (source as StreetsSource).loadStreetsJson(city);
        if (json != null) return json;
      } on ContentSourceException {
        // Fall through to the next tier.
      }
    }
    return null;
  }
}
