import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/content_draft.dart';

/// A whole-file raw-JSON editor, shared by the people/periods screens (and
/// the era editor's "Raw JSON" mode) — `content/people.json` and
/// `content/periods.json` are single shared registries, not one-per-item
/// files, so there's no natural "guided form" to peel individual fields
/// into without a schema change.
class RawJsonFileEditor extends ConsumerStatefulWidget {
  const RawJsonFileEditor({required this.path, required this.title, super.key});

  final String path;
  final String title;

  @override
  ConsumerState<RawJsonFileEditor> createState() => _RawJsonFileEditorState();
}

class _RawJsonFileEditorState extends ConsumerState<RawJsonFileEditor> {
  final _controller = TextEditingController();
  String? _seededFor;
  String? _error;

  void _save() {
    try {
      ref.read(contentDraftProvider.notifier).editFile(widget.path, _controller.text);
      setState(() => _error = null);
      _seededFor = ref.read(contentDraftProvider).valueOrNull!.files[widget.path];
      _controller.text = _seededFor!;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staged — commit from Publish to save for real.')),
      );
    } on FormatException catch (e) {
      setState(() => _error = 'Invalid JSON: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(contentDraftProvider);

    return draft.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Failed to load: $e')),
      data: (draft) {
        final text = draft.files[widget.path] ?? '';
        if (_seededFor != text && _controller.text != text && _seededFor == null) {
          _controller.text = text;
          _seededFor = text;
        }
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 8),
              ],
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: _save, child: const Text('Stage changes')),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
