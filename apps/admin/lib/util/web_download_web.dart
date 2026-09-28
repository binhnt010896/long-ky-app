import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Saves [bytes] as a local file named [filename] via the browser's normal
/// download mechanism — a throwaway `Blob` URL and a synthetic `<a
/// download>` click, revoked right after. The admin is web-only (see
/// `apps/admin/web/`), so there's no non-browser fallback to maintain.
void triggerBrowserDownload(Uint8List bytes, String filename, {String? mimeType}) {
  final blobParts = <JSAny>[bytes.toJS].toJS;
  final blob = mimeType == null
      ? web.Blob(blobParts)
      : web.Blob(blobParts, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
