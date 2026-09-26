import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:video_player/video_player.dart';

import '../api/api_providers.dart';
import '../api/cms_api_client.dart';
import '../state/media_session.dart';
import '../util/image_probe.dart';
import '../util/media_refs.dart';
import '../util/media_urls.dart';

enum _Bg { checker, black, white, magenta }

/// The one replace/upload flow every media-showing screen shares — the
/// Media library, the Era page's Images tab, the Period pane, and People's
/// avatar/full body/portrait slots all open this same dialog, so upload
/// logic (and the aspect-ratio/transparency warnings) lives in exactly one
/// place. On a successful upload it writes to [mediaSessionProvider]
/// itself, so every open screen showing this path updates without the
/// caller having to thread a return value through.
class MediaReplaceDialog extends ConsumerStatefulWidget {
  const MediaReplaceDialog({
    required this.path,
    this.usages = const [],
    required this.manifest,
    super.key,
  });

  final String path;
  final List<MediaUsage> usages;
  final MediaManifest manifest;

  @override
  ConsumerState<MediaReplaceDialog> createState() => _MediaReplaceDialogState();
}

class _MediaReplaceDialogState extends ConsumerState<MediaReplaceDialog> {
  _Bg _bg = _Bg.checker;
  Uint8List? _currentBytes;
  ImageDims? _currentDims;
  bool _loadingCurrent = true;
  VideoPlayerController? _currentVideo;

  PlatformFile? _picked;
  ImageDims? _pickedDims;
  bool _uploading = false;
  String? _error;

  bool get _isVideo => isVideoPath(widget.path);

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final alreadyReplaced = ref.read(mediaSessionProvider)[widget.path];
    if (alreadyReplaced != null && !_isVideo) {
      _currentBytes = alreadyReplaced;
      _currentDims = await probeImage(_currentBytes!);
      setState(() => _loadingCurrent = false);
      return;
    }
    final url = widget.manifest.urlFor(widget.path);
    if (url == null) {
      setState(() => _loadingCurrent = false);
      return;
    }
    if (_isVideo) {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      try {
        await controller.initialize();
        controller
          ..setLooping(true)
          ..setVolume(0)
          ..play();
        _currentVideo = controller;
      } catch (_) {
        controller.dispose();
      }
      if (mounted) setState(() => _loadingCurrent = false);
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
      _pickedDims = null;
      _error = null;
    });
    // Client-side video decoding isn't available here — dimensions/
    // duration for a picked replacement video aren't checked, only its
    // name/size (see the doc comment above and EXECUTION.md's Cycle I).
    if (!_isVideo && file.bytes != null) {
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
      ref.read(mediaSessionProvider.notifier).markReplaced(widget.path, picked.bytes!);
      if (mounted) Navigator.pop(context);
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
    final published = widget.manifest.isPublished(widget.path);
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
              if (widget.usages.isNotEmpty)
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
                          if (!_isVideo)
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
                              child: !_isVideo && _bg == _Bg.checker
                                  ? _Checkerboard(child: _buildPreview())
                                  : _buildPreview(),
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (_loadingCurrent)
                            const Text('Loading…')
                          else if (_isVideo && _currentVideo != null)
                            Text(
                              '${_currentVideo!.value.size.width.toInt()}×${_currentVideo!.value.size.height.toInt()} · '
                              '${_currentVideo!.value.duration.inSeconds}s',
                            )
                          else if (_currentDims != null)
                            Text('${_currentDims!.width}×${_currentDims!.height} · ${(_currentDims!.bytes / 1024).toStringAsFixed(0)} KB')
                          else if (!published)
                            const Text('Not published yet — no preview to show.')
                          else
                            const Text('Could not load a preview.'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 280,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(published ? 'Replace' : 'Upload', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _uploading ? null : _pickFile,
                            icon: const Icon(Icons.attach_file),
                            label: Text(_picked?.name ?? 'Choose file (.${widget.path.split('.').last})'),
                          ),
                          if (_isVideo && _picked != null) ...[
                            const SizedBox(height: 8),
                            Text('New: ${(_picked!.size / 1024 / 1024).toStringAsFixed(1)} MB '
                                '— duration/dimensions aren\'t checked here.'),
                          ] else if (_pickedDims != null) ...[
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
                                : Text(published ? 'Upload replacement' : 'Upload'),
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
    if (_isVideo) {
      final controller = _currentVideo;
      if (controller == null || !controller.value.isInitialized) {
        return const Center(child: Icon(Icons.videocam_off_outlined, size: 48));
      }
      return Center(
        child: AspectRatio(aspectRatio: controller.value.aspectRatio, child: VideoPlayer(controller)),
      );
    }
    final bytes = _picked?.bytes ?? _currentBytes;
    if (bytes == null) {
      return const Center(child: Icon(Icons.image_not_supported_outlined, size: 48));
    }
    return InteractiveViewer(minScale: 1, maxScale: 8, child: Image.memory(bytes, fit: BoxFit.contain));
  }

  @override
  void dispose() {
    _currentVideo?.dispose();
    super.dispose();
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
