import 'content_source.dart';

/// The seam for over-the-air content updates.
///
/// It composes a bundled fallback with an optional [overlay] source. Reads
/// prefer the overlay and fall back to the bundle, so partial OTA payloads
/// work. There is no `sync()` here — the app (`apps/mobile/lib/state/
/// content_sync.dart`) owns fetching, validating (see [ContentPack.
/// parseAndValidate]) and persisting a content pack, and simply assigns
/// [overlay] to a [PackContentSource] once one passes validation. Keeping
/// that entirely outside this package means it never needs Flutter, HTTP or
/// filesystem access.
class OtaContentSource implements ContentSource {
  OtaContentSource({required this.bundled, this.overlay});

  /// Always-present content shipped with the app.
  final ContentSource bundled;

  /// Updated content fetched at runtime, once the app has validated it. Null
  /// until then, or if validation ever fails.
  ContentSource? overlay;

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
