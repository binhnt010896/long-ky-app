import 'clip_player.dart';

/// Non-web fallback so `flutter test` never compiles `package:web`. The
/// admin only ships to web, and tests pass their own fake player.
ClipPlayer createClipPlayer(String url) => _UnsupportedPlayer();

class _UnsupportedPlayer extends ClipPlayer {
  @override
  bool get playing => false;
  @override
  Duration get position => Duration.zero;
  @override
  Duration? get duration => null;
  @override
  String? get error => 'Playback is only available in the browser.';
  @override
  void toggle() {}
  @override
  void seek(Duration to) {}
}
