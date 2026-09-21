import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

/// Plays a looping, muted video (an animated cover) over a still [poster].
///
/// The poster is always painted underneath, so it serves as the instant
/// fade-in image and as the fallback if the video fails to initialize. The
/// video fades in once ready and is scaled to fill the layer like the still.
class SceneVideoLayer extends StatefulWidget {
  const SceneVideoLayer({
    required this.assetKey,
    required this.fit,
    required this.alignment,
    required this.poster,
    super.key,
  });

  /// Bundled asset key, e.g. `assets/content/eras/<era>/cover.mp4`.
  final String assetKey;
  final BoxFit fit;
  final Alignment alignment;
  final Widget poster;

  @override
  State<SceneVideoLayer> createState() => _SceneVideoLayerState();
}

class _SceneVideoLayerState extends State<SceneVideoLayer> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = VideoPlayerController.asset(widget.assetKey);
    try {
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(0);
      await c.play();
      if (!mounted) {
        await c.dispose();
        return;
      }
      _controller = c;
      setState(() => _ready = true);
    } catch (_) {
      // A missing or unplayable video must never break the scene — the poster
      // remains as the static cover.
      await c.dispose();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        widget.poster,
        if (_ready && c != null)
          FittedBox(
            fit: widget.fit,
            alignment: widget.alignment,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: c.value.size.width,
              height: c.value.size.height,
              child: VideoPlayer(c),
            ),
          ),
      ],
    );
  }
}
