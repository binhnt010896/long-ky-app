import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'clip_player.dart';

ClipPlayer createClipPlayer(String url) => _WebClipPlayer(url);

/// A detached `<audio>` element — no CORS needed for plain playback, so the
/// CDN can stay header-free. Cross-origin *fetches* of the manifest would be
/// blocked, which is why clip data comes from `narration-jobs.json` instead.
class _WebClipPlayer extends ClipPlayer {
  _WebClipPlayer(String url) : _audio = web.HTMLAudioElement() {
    _audio
      ..preload = 'metadata'
      ..src = url;
    void on(String type, void Function() f) =>
        _audio.addEventListener(type, ((web.Event _) => f()).toJS);
    on('loadedmetadata', notifyListeners);
    on('timeupdate', notifyListeners);
    on('play', notifyListeners);
    on('pause', notifyListeners);
    on('ended', notifyListeners);
    on('error', () {
      _error = 'Could not load the clip — it may not be published to the CDN yet.';
      notifyListeners();
    });
  }

  final web.HTMLAudioElement _audio;
  String? _error;

  @override
  bool get playing => !_audio.paused && !_audio.ended;

  @override
  Duration get position => Duration(milliseconds: (_audio.currentTime * 1000).round());

  @override
  Duration? get duration {
    final d = _audio.duration;
    if (d.isNaN || d.isInfinite) return null;
    return Duration(milliseconds: (d * 1000).round());
  }

  @override
  String? get error => _error;

  @override
  void toggle() {
    if (_audio.paused) {
      _audio.play().toDart.catchError((Object _) {
        _error = 'Playback was blocked or failed.';
        notifyListeners();
        return null;
      });
    } else {
      _audio.pause();
    }
  }

  @override
  void seek(Duration to) => _audio.currentTime = to.inMilliseconds / 1000;

  @override
  void dispose() {
    _audio
      ..pause()
      ..removeAttribute('src')
      ..load();
    super.dispose();
  }
}
