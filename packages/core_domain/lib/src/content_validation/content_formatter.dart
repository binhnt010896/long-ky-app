import 'dart:convert';

/// Canonical JSON formatting for everything under `content/` — every value
/// on its own line, keys kept in their original (insertion) order, 2-space
/// indent, exactly one trailing newline.
///
/// This is deliberately a plain, uniform expansion rather than the
/// hand-tuned "collapse a short `{vi, en}` object onto one line" style the
/// early content files were written in by hand. A CMS naturally emits this
/// exact shape (e.g. `JSON.stringify(data, null, 2)`), so a single-field
/// edit — whether made by hand or through the CMS — always diffs as just
/// that field, with no bespoke pretty-printer to keep in sync between this
/// Dart code and the CMS's TypeScript.
///
/// Used by `tool/format_content.dart` (the one-time reformat and the CI
/// `--check`), and later by the CMS's own save path.
abstract final class ContentFormatter {
  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  /// Formats already-decoded JSON (typically the `Map`/`List` returned by
  /// [jsonDecode]) to the canonical string.
  static String format(Object? decoded) => '${_encoder.convert(decoded)}\n';

  /// Parses [source] and re-serializes it canonically. Throws
  /// [FormatException] if [source] isn't valid JSON.
  static String reformat(String source) => format(jsonDecode(source));

  /// Whether [source] is already exactly in canonical form.
  static bool isCanonical(String source) => source == reformat(source);
}
