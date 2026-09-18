import 'content_source.dart';

/// The seam for over-the-air content updates.
///
/// It composes a bundled fallback with an optional [overlay] source that a
/// future implementation will populate from a downloaded/cached copy. Reads
/// prefer the overlay and fall back to the bundle, so partial OTA payloads work.
///
/// The [sync] hook is where the OTA fetch will live (download → verify signature
/// → validate against era.schema.json → swap in an overlay source). It is a
/// no-op today; wiring it later must not change the read API above it.
class OtaContentSource implements ContentSource {
  OtaContentSource({required this.bundled, this.overlay});

  /// Always-present content shipped with the app.
  final ContentSource bundled;

  /// Optional updated content fetched at runtime. Null until [sync] provides it.
  ContentSource? overlay;

  /// Fetch and stage newer content. Currently a no-op placeholder — the OTA
  /// pipeline (fetch, verify, validate, atomically swap [overlay]) lands later.
  Future<void> sync() async {
    // TODO(ota): download signed content pack, validate against era.schema.json,
    // then set `overlay` to a source backed by the verified cache.
  }

  @override
  Future<List<String>> availableSlugs() async {
    final result = <String>{...await bundled.availableSlugs()};
    final o = overlay;
    if (o != null) result.addAll(await o.availableSlugs());
    return result.toList();
  }

  @override
  Future<String> loadEraJson(String slug) async {
    final o = overlay;
    if (o != null) {
      try {
        return await o.loadEraJson(slug);
      } on ContentSourceException {
        // Fall through to the bundled copy.
      }
    }
    return bundled.loadEraJson(slug);
  }

  @override
  Future<String> loadPeopleJson() async {
    final o = overlay;
    if (o != null) {
      try {
        return await o.loadPeopleJson();
      } on ContentSourceException {
        // Fall through to the bundled copy.
      }
    }
    return bundled.loadPeopleJson();
  }

  @override
  Future<String> loadPeriodsJson() async {
    final o = overlay;
    if (o != null) {
      try {
        return await o.loadPeriodsJson();
      } on ContentSourceException {
        // Fall through to the bundled copy.
      }
    }
    return bundled.loadPeriodsJson();
  }
}
