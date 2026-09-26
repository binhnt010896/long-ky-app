import 'dart:typed_data';
import 'dart:ui' as ui;

class ImageDims {
  const ImageDims(this.width, this.height, this.bytes);
  final int width;
  final int height;
  final int bytes;

  double get aspect => height == 0 ? 0 : width / height;
}

Future<ImageDims> probeImage(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final dims = ImageDims(frame.image.width, frame.image.height, bytes.length);
  frame.image.dispose();
  return dims;
}

/// PNG only (sources are always PNG or JPG — JPG never has alpha, so a
/// non-PNG here is simply "no alpha channel"). Checks the IHDR color type
/// byte directly rather than decoding pixels: color type 4/6 declares an
/// alpha channel exists, which is the same signal that would have caught
/// the flattened ridge-art regeneration (see [[higgsfield-restore-pitfalls]]).
bool pngHasAlphaChannel(Uint8List bytes) {
  const pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (bytes.length < 26) return false;
  for (var i = 0; i < 8; i++) {
    if (bytes[i] != pngSignature[i]) return false;
  }
  final colorType = bytes[25];
  return colorType == 4 || colorType == 6;
}
