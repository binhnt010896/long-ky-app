import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/media_session.dart';
import '../util/media_refs.dart';
import '../util/media_urls.dart';
import 'media_replace_dialog.dart';

/// One asset path, shown inline wherever it's used — the Era page's Images
/// tab, the Period pane, and People's avatar/full body/portrait fields all
/// use this instead of a "go to the Media library" link, so replacing an
/// image happens on the page the admin is already looking at. Media
/// library grid tiles are the same information at a smaller [size].
class MediaSlot extends ConsumerWidget {
  const MediaSlot({
    required this.label,
    required this.path,
    required this.manifest,
    this.usages = const [],
    this.size = 160,
    this.caption,
    super.key,
  });

  final String label;

  /// Null shows an empty slot with an Upload affordance disabled — the
  /// caller (e.g. a person with no avatar yet) should offer its own "Add…"
  /// action to create the path first, not this widget.
  final String? path;
  final MediaManifest manifest;
  final List<MediaUsage> usages;
  final double size;
  final String? caption;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = this.path;
    final justReplaced = path == null ? null : ref.watch(mediaSessionProvider)[path];
    final published = path != null && manifest.isPublished(path);
    final isVideo = path != null && isVideoPath(path);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        if (caption != null)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 6),
            child: Text(caption!, style: Theme.of(context).textTheme.bodySmall),
          )
        else
          const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: path == null ? null : () => _openReplace(context, ref, path),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: path == null
                          ? const Center(child: Icon(Icons.add_photo_alternate_outlined, size: 32))
                          : _Thumbnail(
                              path: path,
                              url: manifest.urlFor(path),
                              justReplacedBytes: justReplaced,
                              isVideo: isVideo,
                            ),
                    ),
                    if (justReplaced != null)
                      const Positioned(top: 4, left: 4, child: _Badge(text: 'Replaced', color: Colors.blue))
                    else if (path != null && !published)
                      const Positioned(top: 4, left: 4, child: _Badge(text: 'Missing', color: Colors.red)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(path ?? 'not set', style: Theme.of(context).textTheme.bodySmall),
                  if (path != null && !published && justReplaced == null)
                    Text('Not published yet', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  if (path != null)
                    TextButton(
                      onPressed: () => _openReplace(context, ref, path),
                      child: Text(published || justReplaced != null ? 'Replace…' : 'Upload…'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _openReplace(BuildContext context, WidgetRef ref, String path) {
    showDialog<void>(
      context: context,
      builder: (context) => MediaReplaceDialog(path: path, usages: usages, manifest: manifest),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.path, required this.url, required this.justReplacedBytes, required this.isVideo});

  final String path;
  final String? url;
  final Uint8List? justReplacedBytes;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    if (isVideo) {
      // A per-tile live video preview isn't worth it in a grid of many
      // slots; the icon is enough here, and MediaReplaceDialog plays it.
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.play_circle_outline, size: 32)),
      );
    }
    if (justReplacedBytes != null) {
      return Image.memory(justReplacedBytes!, fit: BoxFit.cover);
    }
    if (url == null) {
      return const Center(child: Icon(Icons.image_not_supported_outlined, size: 32));
    }
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.error_outline, size: 32)),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10)),
    );
  }
}
