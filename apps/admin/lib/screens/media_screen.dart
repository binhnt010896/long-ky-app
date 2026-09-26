import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';

import '../api/api_providers.dart';
import '../api/cms_api_client.dart';

/// Uploads/previews originals in the private `long-ky-sources` bucket via
/// the Worker's `/media` endpoint — never touches R2 directly. Preview
/// includes an [InteractiveViewer] so the admin can zoom into corners,
/// the same transparency check used when generating era art
/// (see EXECUTION.md / [[higgsfield-restore-pitfalls]]).
class MediaScreen extends ConsumerStatefulWidget {
  const MediaScreen({super.key});

  @override
  ConsumerState<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends ConsumerState<MediaScreen> {
  final _pathController = TextEditingController();
  PlatformFile? _picked;
  Uint8List? _previewBytes;
  bool _busy = false;
  String? _status;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _picked = result.files.first;
      if (_pathController.text.isEmpty) {
        _pathController.text = _picked!.name;
      }
    });
  }

  Future<void> _upload() async {
    final picked = _picked;
    final path = _pathController.text.trim();
    if (picked == null || picked.bytes == null || path.isEmpty) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final contentType = lookupMimeType(picked.name) ?? 'application/octet-stream';
      await ref
          .read(cmsApiClientProvider)
          .putMedia(path: path, bytes: picked.bytes!, contentType: contentType);
      setState(() => _status = 'Uploaded to long-ky-sources/$path');
    } on CmsApiException catch (e) {
      setState(() => _status = 'Upload failed: ${e.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preview() async {
    final path = _pathController.text.trim();
    if (path.isEmpty) return;
    setState(() {
      _busy = true;
      _status = null;
      _previewBytes = null;
    });
    try {
      final bytes = await ref.read(cmsApiClientProvider).getMedia(path);
      setState(() => _previewBytes = bytes);
    } on CmsApiException catch (e) {
      setState(() => _status = 'Preview failed: ${e.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Media', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Originals live in the private long-ky-sources bucket — publish '
            'converts them to WebP on the public CDN.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pathController,
                  decoration: const InputDecoration(
                    labelText: 'Path (e.g. eras/hai-ba-trung/scene/ridge-far.png)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickFile,
                icon: const Icon(Icons.attach_file),
                label: Text(_picked?.name ?? 'Choose file'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _busy || _picked == null ? null : _upload,
                icon: const Icon(Icons.upload),
                label: const Text('Upload'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _preview,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Load preview'),
              ),
              if (_busy) ...[
                const SizedBox(width: 12),
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ],
          ),
          if (_status != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_status!)),
          const SizedBox(height: 16),
          if (_previewBytes != null)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                ),
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 8,
                  child: Image.memory(_previewBytes!, fit: BoxFit.contain),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }
}
