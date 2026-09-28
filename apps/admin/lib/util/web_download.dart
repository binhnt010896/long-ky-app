// Conditional export so `flutter test` (Dart VM) never has to compile
// `package:web` — only reached when actually compiling for a browser.
export 'web_download_stub.dart' if (dart.library.js_interop) 'web_download_web.dart';
