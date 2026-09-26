import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bytes uploaded this session, keyed by source path — shown instead of the
/// (stale, pre-publish) CDN copy until the next publish catches up. A
/// provider rather than screen-local state so replacing an image from the
/// Era page, the Period pane, the People page or the Media library all
/// show the same result immediately, wherever else that path appears.
class MediaSessionController extends Notifier<Map<String, Uint8List>> {
  @override
  Map<String, Uint8List> build() => const {};

  void markReplaced(String path, Uint8List bytes) {
    state = {...state, path: bytes};
  }
}

final mediaSessionProvider = NotifierProvider<MediaSessionController, Map<String, Uint8List>>(
  MediaSessionController.new,
);
