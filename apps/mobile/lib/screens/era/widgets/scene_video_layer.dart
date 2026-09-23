import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import '../../../theme/content_assets.dart';

/// Plays a looping, muted video (an animated cover) over a still [poster].
///
/// The poster is always painted underneath, so it serves as the instant
/// fade-in image and as the fallback if the video fails to download or
/// initialize. The video fades in once ready and is scaled to fill the layer
/// like the still.
class SceneVideoLayer extends StatefulWidget {
  const SceneVideoLayer({
    required this.path,
    required this.fit,
    required this.alignment,
    required this.poster,
    super.key,
  });

  /// Content-relative media path, e.g. `eras/<era>/cover.mp4`.
  final String path;
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
    // Widget tests substitute debugContentImageOverride and must never touch
    // the network, the cache plugin or a video platform channel.
    if (debugContentImageOverride != null) return;
    final url = ContentMedia.url(widget.path);
    VideoPlayerController? c;
    try {
      if (kIsWeb) {
        c = VideoPlayerController.networkUrl(Uri.parse(url));
      } else {
        // Download once into the shared media cache, then play from disk:
        // covers loop forever, so streaming would re-download on every visit.
        final file = await ContentMedia.cache.getSingleFile(url);
        if (!mounted) return;
        c = VideoPlayerController.file(file);
      }
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
      await c?.dispose();
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
