import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:viet_su/theme/content_assets.dart';

/// A valid, decodable 1×1 transparent PNG, so every content image resolves
/// synchronously in widget tests without touching the network or the R2 cache
/// plugin.
final Uint8List kTransparentPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

/// Flutter runs this automatically for every test in this package, before
/// `main()`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  debugContentImageOverride = (_) => MemoryImage(kTransparentPng);
  await testMain();
}
