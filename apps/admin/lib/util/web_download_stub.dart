import 'dart:typed_data';

/// Non-web fallback so `flutter test` (which runs widget tests on the Dart
/// VM, not a browser) never has to compile `package:web`. The admin only
/// ever ships to web — this is never called there. Tests always pass their
/// own `saveFile` override to [MediaReplaceDialog], so this default is
/// never invoked in practice either.
void triggerBrowserDownload(Uint8List bytes, String filename, {String? mimeType}) {
  throw UnsupportedError('triggerBrowserDownload is only available on web.');
}
