import 'package:flutter/widgets.dart';

/// Where bundled content assets live, and how to turn a content-relative path
/// (as stored in `content/eras/*.json`, e.g. `eras/hong-bang/scene/sky.png`)
/// into a Flutter asset key. Keeping JSON paths content-root-relative keeps the
/// content portable (an OTA source can serve the same paths from its own base).
const String kContentAssetBase = 'assets/content';

/// Resolve a content-relative asset path to a bundle key for `Image.asset`.
String contentAssetKey(String contentRelativePath) =>
    '$kContentAssetBase/$contentRelativePath';

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
