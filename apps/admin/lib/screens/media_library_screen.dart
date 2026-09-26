import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/content_draft.dart';
import '../state/media_session.dart';
import '../util/media_refs.dart';
import '../util/media_urls.dart';
import '../widgets/media_replace_dialog.dart';

/// The real media library: every image/video the draft actually
/// references, grouped by where it's used, with its published dimensions
/// and a replace-in-place flow (shared with the inline [MediaSlot]s on the
/// Era, Period and People pages via [MediaReplaceDialog] and
/// [mediaSessionProvider]) — see EXECUTION.md's Cycle H (H-4) and Cycle I.
class MediaLibraryScreen extends ConsumerStatefulWidget {
  const MediaLibraryScreen({this.focusPath, super.key});

  /// Set when navigated here from a "Manage in Media Library" link — opens
  /// that item's detail immediately.
  final String? focusPath;

  @override
  ConsumerState<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends ConsumerState<MediaLibraryScreen> {
  String _query = '';
  bool _missingOnly = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusPath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openDetail(widget.focusPath!));
    }
  }

  void _openDetail(String path) {
    final draft = ref.read(contentDraftProvider).valueOrNull;
    if (draft == null) return;
    final refs = collectMediaRefs(draft);
    final manifest = MediaManifest.fromJson(draft.files['content/media-manifest.json']!);
    showDialog<void>(
      context: context,
      builder: (context) => MediaReplaceDialog(path: path, usages: refs[path] ?? const [], manifest: manifest),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(contentDraftProvider);
    final justReplaced = ref.watch(mediaSessionProvider);

    return draft.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Failed to load: $e')),
      data: (draft) {
        final refs = collectMediaRefs(draft);
        final manifest = MediaManifest.fromJson(draft.files['content/media-manifest.json']!);
        var paths = refs.keys.toList()..sort();

        if (_query.trim().isNotEmpty) {
          final q = _query.toLowerCase();
          paths = paths.where((p) {
            final usageText = refs[p]!.map((u) => u.toString()).join(' ').toLowerCase();
            return p.toLowerCase().contains(q) || usageText.contains(q);
          }).toList();
        }
        if (_missingOnly) {
          paths = paths.where((p) => !manifest.isPublished(p) && !justReplaced.containsKey(p)).toList();
        }

        final missingCount = refs.keys.where((p) => !manifest.isPublished(p)).length;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Media (${refs.length})', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(width: 12),
                  if (missingCount > 0)
                    Chip(
                      label: Text('$missingCount missing'),
                      backgroundColor: Theme.of(context).colorScheme.errorContainer,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search path or usage',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilterChip(
                    label: const Text('Missing only'),
                    selected: _missingOnly,
                    onSelected: (v) => setState(() => _missingOnly = v),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: paths.length,
                  itemBuilder: (context, i) {
                    final path = paths[i];
                    return _MediaTile(
                      path: path,
                      usages: refs[path] ?? const [],
                      manifest: manifest,
                      onTap: () => _openDetail(path),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MediaTile extends ConsumerWidget {
  const _MediaTile({required this.path, required this.usages, required this.manifest, required this.onTap});

  final String path;
  final List<MediaUsage> usages;
  final MediaManifest manifest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final justReplaced = ref.watch(mediaSessionProvider)[path];
    final url = manifest.urlFor(path);
    final published = url != null;
    final isVideo = isVideoPath(path);

    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).colorScheme.outline),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: isVideo
                      ? Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: const Center(child: Icon(Icons.play_circle_outline, size: 32)),
                        )
                      : (justReplaced != null
                            ? Image.memory(justReplaced, fit: BoxFit.cover)
                            : (published
                                  ? Image.network(url, fit: BoxFit.cover)
                                  : const Center(child: Icon(Icons.image_not_supported_outlined)))),
                ),
                if (justReplaced != null)
                  const Positioned(top: 4, left: 4, child: _Badge(text: 'Replaced', color: Colors.blue))
                else if (!published)
                  const Positioned(top: 4, left: 4, child: _Badge(text: 'Missing', color: Colors.red)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            usages.isEmpty ? path : usages.first.toString(),
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (usages.length > 1)
            Text('+${usages.length - 1} more', style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
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
