import 'dart:convert';

import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/content_draft.dart';

/// Edits `content/eras/<slug>.json`. Title/kicker/subtitle/overview get a
/// guided bilingual form (the fields an admin touches most); events,
/// characters, citations and everything else go through the raw-JSON
/// fallback, still gated by the same [ContentValidator] the CLI/CI use.
class EraEditorScreen extends ConsumerStatefulWidget {
  const EraEditorScreen({required this.slug, super.key});

  final String slug;

  @override
  ConsumerState<EraEditorScreen> createState() => _EraEditorScreenState();
}

class _EraEditorScreenState extends ConsumerState<EraEditorScreen> {
  bool _rawMode = false;
  late TextEditingController _rawController;
  String? _rawError;

  final _titleVi = TextEditingController();
  final _titleEn = TextEditingController();
  final _kickerVi = TextEditingController();
  final _kickerEn = TextEditingController();
  final _subtitleVi = TextEditingController();
  final _subtitleEn = TextEditingController();
  final _overviewVi = TextEditingController();
  final _overviewEn = TextEditingController();

  String get _path => 'content/eras/${widget.slug}.json';

  @override
  void initState() {
    super.initState();
    _rawController = TextEditingController();
  }

  void _seedFrom(String json) {
    _rawController.text = json;
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      _titleVi.text = _localized(decoded['title'], 'vi');
      _titleEn.text = _localized(decoded['title'], 'en');
      _kickerVi.text = _localized(decoded['kicker'], 'vi');
      _kickerEn.text = _localized(decoded['kicker'], 'en');
      _subtitleVi.text = _localized(decoded['subtitle'], 'vi');
      _subtitleEn.text = _localized(decoded['subtitle'], 'en');
      _overviewVi.text = _localized(decoded['overview'], 'vi');
      _overviewEn.text = _localized(decoded['overview'], 'en');
    } catch (_) {
      // Leave the guided fields blank — the raw editor still shows it.
    }
  }

  String _localized(Object? field, String lang) {
    if (field is Map<String, dynamic>) return field[lang] as String? ?? '';
    return '';
  }

  void _saveGuided() {
    final current = ref.read(contentDraftProvider).valueOrNull;
    if (current == null) return;
    try {
      final decoded = jsonDecode(current.files[_path]!) as Map<String, dynamic>;
      decoded['title'] = {'vi': _titleVi.text, 'en': _titleEn.text};
      decoded['kicker'] = {'vi': _kickerVi.text, 'en': _kickerEn.text};
      decoded['subtitle'] = {'vi': _subtitleVi.text, 'en': _subtitleEn.text};
      decoded['overview'] = {'vi': _overviewVi.text, 'en': _overviewEn.text};
      final text = ContentFormatter.format(decoded);
      ref.read(contentDraftProvider.notifier).editFile(_path, text);
      _rawController.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staged — commit from Publish to save for real.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  void _saveRaw() {
    final current = ref.read(contentDraftProvider).valueOrNull;
    if (current == null) return;
    try {
      ref.read(contentDraftProvider.notifier).editFile(_path, _rawController.text);
      setState(() => _rawError = null);
      _seedFrom(ref.read(contentDraftProvider).valueOrNull!.files[_path]!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staged — commit from Publish to save for real.')),
      );
    } on FormatException catch (e) {
      setState(() => _rawError = 'Invalid JSON: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(contentDraftProvider);

    return draft.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Failed to load: $e')),
      data: (draft) {
        final text = draft.files[_path];
        if (text == null) {
          return Center(child: Text('${widget.slug} not found in the loaded draft.'));
        }
        if (_rawController.text.isEmpty) _seedFrom(text);

        final result = draft.validate();
        final issues = result.issues.where((i) => i.file == '${widget.slug}.json').toList();

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/eras'),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Text(widget.slug, style: Theme.of(context).textTheme.headlineSmall),
                  ),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Guided')),
                      ButtonSegment(value: true, label: Text('Raw JSON')),
                    ],
                    selected: {_rawMode},
                    onSelectionChanged: (s) => setState(() => _rawMode = s.first),
                  ),
                ],
              ),
              if (issues.isNotEmpty) ...[
                const SizedBox(height: 8),
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final issue in issues) Text('• ${issue.message}'),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Expanded(child: _rawMode ? _buildRaw() : _buildGuided()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGuided() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bilingualRow('Title', _titleVi, _titleEn),
          _bilingualRow('Kicker', _kickerVi, _kickerEn),
          _bilingualRow('Subtitle', _subtitleVi, _subtitleEn),
          _bilingualRow('Overview', _overviewVi, _overviewEn, maxLines: 6),
          const SizedBox(height: 16),
          Text(
            'Events, characters, citations and everything else are edited '
            'via Raw JSON for now.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _saveGuided, child: const Text('Stage changes')),
        ],
      ),
    );
  }

  Widget _bilingualRow(
    String label,
    TextEditingController vi,
    TextEditingController en, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Padding(padding: const EdgeInsets.only(top: 12), child: Text(label)),
          ),
          Expanded(
            child: TextField(
              controller: vi,
              maxLines: maxLines,
              decoration: const InputDecoration(labelText: 'vi', border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: en,
              maxLines: maxLines,
              decoration: const InputDecoration(labelText: 'en', border: OutlineInputBorder()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRaw() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_rawError != null) ...[
          Text(_rawError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 8),
        ],
        Expanded(
          child: TextField(
            controller: _rawController,
            maxLines: null,
            expands: true,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _saveRaw, child: const Text('Stage changes')),
      ],
    );
  }

  @override
  void dispose() {
    _rawController.dispose();
    for (final c in [
      _titleVi,
      _titleEn,
      _kickerVi,
      _kickerEn,
      _subtitleVi,
      _subtitleEn,
      _overviewVi,
      _overviewEn,
    ]) {
      c.dispose();
    }
    super.dispose();
  }
}
