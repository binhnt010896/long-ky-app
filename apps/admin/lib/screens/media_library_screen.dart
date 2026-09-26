import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

import '../api/api_providers.dart';
import '../api/cms_api_client.dart';
import '../state/content_draft.dart';
import '../util/image_probe.dart';
import '../util/media_refs.dart';
import '../util/media_urls.dart';

/// The real media library: every image the draft actually references,
/// grouped by where it's used, with its published dimensions and a
/// replace-in-place flow. Replaces the old path-typing Media screen — see
/// EXECUTION.md's Cycle H (H-4).
class MediaLibraryScreen extends ConsumerStatefulWidget {
  const MediaLibraryScreen({this.focusPath, super.key});

  /// Set when navigated here from an [AssetRefField]'s "Manage in Media
  /// Library" link — opens that item's detail immediately.
  final String? focusPath;

  @override
  ConsumerState<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends ConsumerState<MediaLibraryScreen> {
  String _query = '';
  bool _missingOnly = false;

  /// Bytes uploaded this session, keyed by source path — shown instead of
  /// the (stale, pre-publish) CDN copy until the next publish catches up.
  final Map<String, Uint8List> _justReplaced = {};

  @override
  void initState() {
    super.initState();
    if (widget.focusPath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openDetail(widget.focusPath!));
    }
  }

  Future<void> _openDetail(String path) async {
    final draft = ref.read(contentDraftProvider).valueOrNull;
    if (draft == null) return;
    final refs = collectMediaRefs(draft);
    final manifest = MediaManifest.fromJson(draft.files['content/media-manifest.json']!);
    final replacedBytes = await showDialog<Uint8List>(
      context: context,
      builder: (context) => _MediaDetailDialog(
        path: path,
        usages: refs[path] ?? const [],
        manifest: manifest,
        alreadyReplaced: _justReplaced[path],
      ),
    );
    if (replacedBytes != null) {
      setState(() => _justReplaced[path] = replacedBytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(contentDraftProvider);

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
          paths = paths.where((p) => !manifest.isPublished(p) && !_justReplaced.containsKey(p)).toList();
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
                      justReplacedBytes: _justReplaced[path],
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

class _MediaTile extends StatelessWidget {
  const _MediaTile({
    required this.path,
    required this.usages,
    required this.manifest,
    required this.justReplacedBytes,
    required this.onTap,
  });

  final String path;
  final List<MediaUsage> usages;
  final MediaManifest manifest;
  final Uint8List? justReplacedBytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final url = manifest.urlFor(path);
    final published = url != null;

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
                  child: justReplacedBytes != null
                      ? Image.memory(justReplacedBytes!, fit: BoxFit.cover)
                      : (published
                            ? Image.network(url, fit: BoxFit.cover)
                            : const Center(child: Icon(Icons.image_not_supported_outlined))),
                ),
                if (justReplacedBytes != null)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: _Badge(text: 'Replaced', color: Colors.blue),
                  )
                else if (!published)
                  Positioned(top: 4, left: 4, child: _Badge(text: 'Missing', color: Colors.red)),
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

enum _Bg { checker, black, white, magenta }

class _MediaDetailDialog extends ConsumerStatefulWidget {
  const _MediaDetailDialog({
    required this.path,
    required this.usages,
    required this.manifest,
    required this.alreadyReplaced,
  });

  final String path;
  final List<MediaUsage> usages;
  final MediaManifest manifest;
  final Uint8List? alreadyReplaced;

  @override
  ConsumerState<_MediaDetailDialog> createState() => _MediaDetailDialogState();
}

class _MediaDetailDialogState extends ConsumerState<_MediaDetailDialog> {
  _Bg _bg = _Bg.checker;
  Uint8List? _currentBytes;
  ImageDims? _currentDims;
  bool _loadingCurrent = true;

  PlatformFile? _picked;
  ImageDims? _pickedDims;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    if (widget.alreadyReplaced != null) {
      _currentBytes = widget.alreadyReplaced;
      _currentDims = await probeImage(_currentBytes!);
      setState(() => _loadingCurrent = false);
      return;
    }
    final url = widget.manifest.urlFor(widget.path);
    if (url == null) {
      setState(() => _loadingCurrent = false);
      return;
    }
    try {
      final res = await http.get(Uri.parse(url));
      _currentBytes = res.bodyBytes;
      _currentDims = await probeImage(_currentBytes!);
    } catch (_) {
      // Leave dims null — the dialog still shows the path/usages.
    }
    if (mounted) setState(() => _loadingCurrent = false);
  }

  Future<void> _pickFile() async {
    final expectedExt = widget.path.split('.').last.toLowerCase();
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: [expectedExt],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    setState(() {
      _picked = file;
      _error = null;
    });
    if (file.bytes != null) {
      _pickedDims = await probeImage(file.bytes!);
      setState(() {});
    }
  }

  List<String> get _warnings {
    final warnings = <String>[];
    final picked = _pickedDims;
    final current = _currentDims;
    if (picked == null) return warnings;
    if (current != null) {
      final ratioDiff = (picked.aspect - current.aspect).abs() / (current.aspect == 0 ? 1 : current.aspect);
      if (ratioDiff > 0.01) {
        warnings.add(
          'Aspect ratio differs: ${current.width}×${current.height} → ${picked.width}×${picked.height}',
        );
      }
      if (picked.width < current.width || picked.height < current.height) {
        warnings.add('New image is smaller than the current one.');
      }
    }
    if (_picked?.name.toLowerCase().endsWith('.png') == true) {
      final currentHasAlpha = _currentBytes != null && pngHasAlphaChannel(_currentBytes!);
      final newHasAlpha = pngHasAlphaChannel(_picked!.bytes!);
      if (currentHasAlpha && !newHasAlpha) {
        warnings.add(
          'Current image has transparency; the new one does not — this will flatten it opaque.',
        );
      }
    }
    return warnings;
  }

  Future<void> _confirmUpload() async {
    final picked = _picked;
    if (picked?.bytes == null) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final contentType = lookupMimeType(picked!.name) ?? 'application/octet-stream';
      await ref
          .read(cmsApiClientProvider)
          .putMedia(path: widget.path, bytes: picked.bytes!, contentType: contentType);
      if (mounted) Navigator.pop(context, picked.bytes);
    } on CmsApiException catch (e) {
      setState(() => _error = 'Upload failed: ${e.message}');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Color? get _bgColor => switch (_bg) {
    _Bg.checker => null,
    _Bg.black => Colors.black,
    _Bg.white => Colors.white,
    _Bg.magenta => const Color(0xFFFF00FF),
  };

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(widget.path, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [for (final u in widget.usages) Chip(label: Text(u.toString()))],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Text('Background: '),
                              for (final b in _Bg.values)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: ChoiceChip(
                                    label: Text(b.name),
                                    selected: _bg == b,
                                    onSelected: (_) => setState(() => _bg = b),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: _bgColor,
                                border: Border.all(color: Theme.of(context).colorScheme.outline),
                              ),
                              child: _bg == _Bg.checker
                                  ? _Checkerboard(child: _buildPreview())
                                  : _buildPreview(),
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (_loadingCurrent)
                            const Text('Loading…')
                          else if (_currentDims != null)
                            Text('${_currentDims!.width}×${_currentDims!.height} · ${(_currentDims!.bytes / 1024).toStringAsFixed(0)} KB')
                          else
                            const Text('Not published yet — no dimensions to show.'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 280,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Replace', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _uploading ? null : _pickFile,
                            icon: const Icon(Icons.attach_file),
                            label: Text(_picked?.name ?? 'Choose file (.${widget.path.split('.').last})'),
                          ),
                          if (_pickedDims != null) ...[
                            const SizedBox(height: 8),
                            Text('New: ${_pickedDims!.width}×${_pickedDims!.height} · ${(_pickedDims!.bytes / 1024).toStringAsFixed(0)} KB'),
                          ],
                          for (final w in _warnings)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.warning_amber, size: 16, color: Theme.of(context).colorScheme.error),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text(w, style: Theme.of(context).textTheme.bodySmall)),
                                ],
                              ),
                            ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                            ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _picked == null || _uploading ? null : _confirmUpload,
                            child: _uploading
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('Upload replacement'),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'The old original is backed up in long-ky-sources before it\'s '
                            'overwritten. Nothing changes on the public site until the next publish.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final bytes = _picked?.bytes ?? _currentBytes;
    if (bytes == null) {
      return const Center(child: Icon(Icons.image_not_supported_outlined, size: 48));
    }
    return InteractiveViewer(minScale: 1, maxScale: 8, child: Image.memory(bytes, fit: BoxFit.contain));
  }
}

class _Checkerboard extends StatelessWidget {
  const _Checkerboard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [CustomPaint(painter: _CheckerPainter()), child],
    );
  }
}

class _CheckerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cell = 12.0;
    final light = Paint()..color = const Color(0xFFCCCCCC);
    final dark = Paint()..color = const Color(0xFF999999);
    for (var y = 0.0; y < size.height; y += cell) {
      for (var x = 0.0; x < size.width; x += cell) {
        final isDark = ((x ~/ cell) + (y ~/ cell)).isEven;
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), isDark ? dark : light);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
