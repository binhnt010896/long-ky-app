import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../util/clip_player.dart';
import '../util/narration.dart';

/// The Vietnamese narration for one event or person: play it, scrub through
/// it, read the script that was voiced, open the published file. Read-only —
/// clips are generated and published from the repo's `tool/` scripts.
class NarrationPanel extends StatefulWidget {
  const NarrationPanel({
    required this.clip,
    this.playerFactory = createClipPlayer,
    super.key,
  });

  /// Null (or not yet generated) shows the empty state.
  final NarrationClip? clip;

  /// Test seam: the real player is a browser `<audio>` element.
  final ClipPlayer Function(String url) playerFactory;

  @override
  State<NarrationPanel> createState() => _NarrationPanelState();
}

class _NarrationPanelState extends State<NarrationPanel> {
  ClipPlayer? _player;

  /// Created on first play, so a page full of panels doesn't open a network
  /// connection per clip.
  ClipPlayer _ensurePlayer(NarrationClip clip) {
    final existing = _player;
    if (existing != null) return existing;
    final p = widget.playerFactory(clip.url)..addListener(() => setState(() {}));
    return _player = p;
  }

  @override
  void didUpdateWidget(NarrationPanel old) {
    super.didUpdateWidget(old);
    // A regenerated clip has a new `?v=` — drop the player of the old one.
    if (old.clip?.url != widget.clip?.url) {
      _player?.dispose();
      _player = null;
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clip = widget.clip;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.headphones_outlined, size: 20),
                const SizedBox(width: 8),
                Text('Narration (Vietnamese)', style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            if (clip == null || !clip.isReady)
              Text(
                clip == null
                    ? 'No narration for this item.'
                    : 'Narration is queued but not generated yet.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
              )
            else
              ..._ready(context, clip),
          ],
        ),
      ),
    );
  }

  List<Widget> _ready(BuildContext context, NarrationClip clip) {
    final theme = Theme.of(context);
    final player = _player;
    final total = player?.duration ?? clip.duration ?? Duration.zero;
    final pos = player?.position ?? Duration.zero;
    final max = total.inMilliseconds.toDouble();
    final value = max <= 0 ? 0.0 : pos.inMilliseconds.clamp(0, total.inMilliseconds).toDouble();
    final error = player?.error;

    return [
      Row(
        children: [
          IconButton.filledTonal(
            tooltip: player?.playing == true ? 'Pause' : 'Play',
            icon: Icon(player?.playing == true ? Icons.pause : Icons.play_arrow),
            onPressed: () => _ensurePlayer(clip).toggle(),
          ),
          Expanded(
            child: Slider(
              value: value,
              max: max <= 0 ? 1 : max,
              onChanged: player == null || max <= 0
                  ? null
                  : (v) => player.seek(Duration(milliseconds: v.round())),
            ),
          ),
          Text('${formatClock(pos)} / ${formatClock(total)}', style: theme.textTheme.bodySmall),
        ],
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(error, style: TextStyle(color: theme.colorScheme.error)),
        ),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Chip(label: Text('${clip.chars} chars'), visualDensity: VisualDensity.compact),
          Chip(label: Text('v ${clip.hash}'), visualDensity: VisualDensity.compact),
          TextButton.icon(
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Open mp3'),
            onPressed: () => launchUrl(Uri.parse(clip.url)),
          ),
          TextButton.icon(
            icon: const Icon(Icons.link, size: 18),
            label: const Text('Copy link'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: clip.url));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Clip URL copied.')),
              );
            },
          ),
        ],
      ),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Script read aloud'),
        subtitle: const Text(
          'As spoken when the clip was generated. After editing the text, '
          'regenerate with tool/narration_jobs.mjs.',
        ),
        children: [Align(alignment: Alignment.centerLeft, child: SelectableText(clip.text))],
      ),
    ];
  }
}

/// A small headphones mark for list rows: present only when the item has a
/// generated clip; the tooltip carries its length.
class NarrationBadge extends StatelessWidget {
  const NarrationBadge({required this.clip, super.key});
  final NarrationClip? clip;

  @override
  Widget build(BuildContext context) {
    final c = clip;
    if (c == null || !c.isReady) return const SizedBox.shrink();
    final d = c.duration;
    return Tooltip(
      message: d == null ? 'Has narration' : 'Narration · ${formatClock(d)}',
      child: Icon(Icons.headphones_outlined, size: 18, color: Theme.of(context).hintColor),
    );
  }
}
