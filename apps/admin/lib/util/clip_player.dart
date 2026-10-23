import 'package:flutter/foundation.dart';

import 'clip_player_stub.dart' if (dart.library.js_interop) 'clip_player_web.dart'
    as impl;

/// Plays one narration clip. Abstract so widget tests (Dart VM, no browser)
/// can supply a fake; the real one is a browser `<audio>` element.
abstract class ClipPlayer extends ChangeNotifier {
  bool get playing;
  Duration get position;
  Duration? get duration;

  /// A human-readable reason playback failed (not on the CDN yet, offline, no
  /// browser), or null.
  String? get error;

  void toggle();
  void seek(Duration to);
}

/// The platform's player for [url]: a browser `<audio>` element on web, an
/// inert one elsewhere.
ClipPlayer createClipPlayer(String url) => impl.createClipPlayer(url);
