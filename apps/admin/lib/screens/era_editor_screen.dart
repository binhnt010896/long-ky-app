import 'dart:convert';

import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/content_draft.dart';
import '../util/media_urls.dart';
import '../widgets/media_slot.dart';

enum _EraTab { guided, images, raw }

/// Edits `content/eras/<slug>.json`. Title/kicker/subtitle/overview get a
/// guided bilingual form (the fields an admin touches most); an Images tab
/// covers cover/scene-layer/event-hero art inline (Cycle I); events,
/// characters, citations and everything else go through the raw-JSON
/// fallback, still gated by the same [ContentValidator] the CLI/CI use.
class EraEditorScreen extends ConsumerStatefulWidget {
  const EraEditorScreen({required this.slug, super.key});

  final String slug;

  @override
  ConsumerState<EraEditorScreen> createState() => _EraEditorScreenState();
}

class _EraEditorScreenState extends ConsumerState<EraEditorScreen> {
  _EraTab _tab = _EraTab.guided;
  late TextEditingController _rawController;
  String? _rawError;
  bool _draft = false;

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
      _draft = decoded['draft'] == true;
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
      if (_draft) {
        decoded['draft'] = true;
      } else {
        decoded.remove('draft');
      }
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
                  Text(widget.slug, style: Theme.of(context).textTheme.headlineSmall),
                  if (_draft) ...[
                    const SizedBox(width: 8),
                    Chip(
                      label: const Text('DRAFT'),
                      backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                    ),
                  ],
                  const Spacer(),
                  SegmentedButton<_EraTab>(
                    segments: const [
                      ButtonSegment(value: _EraTab.guided, label: Text('Guided')),
                      ButtonSegment(value: _EraTab.images, label: Text('Images')),
                      ButtonSegment(value: _EraTab.raw, label: Text('Raw JSON')),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (s) => setState(() => _tab = s.first),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Delete era',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _confirmDelete,
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
              Expanded(
                child: switch (_tab) {
                  _EraTab.guided => _buildGuided(),
                  _EraTab.images => _buildImages(draft, text),
                  _EraTab.raw => _buildRaw(),
                },
              ),
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
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _draft,
            title: const Text('Draft'),
            subtitle: const Text(
              'Still valid content, but excluded from the next publish — '
              'installed apps never receive it over the air.',
            ),
            onChanged: (v) => setState(() => _draft = v ?? false),
          ),
          const SizedBox(height: 8),
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

  Widget _buildImages(ContentDraft draft, String eraJsonText) {
    Map<String, dynamic> era;
    try {
      era = jsonDecode(eraJsonText) as Map<String, dynamic>;
    } catch (e) {
      return Center(child: Text('Invalid JSON — fix it in Raw JSON first: $e'));
    }
    final manifest = MediaManifest.fromJson(draft.files['content/media-manifest.json']!);
    String? sourceOf(Object? ref) =>
        ref is Map ? ((ref['flagship'] as String?) ?? (ref['reduced'] as String?)) : null;

    final layers = ((era['scene'] as Map?)?['layers'] as List?) ?? const [];
    final events = (era['events'] as List? ?? const []).cast<Map<String, dynamic>>();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MediaSlot(label: 'Cover', path: sourceOf(era['cover']), manifest: manifest),
          const SizedBox(height: 20),
          if (layers.isNotEmpty) ...[
            Text('Scene layers', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (var i = 0; i < layers.length; i++) ...[
              if (layers[i] is Map && sourceOf(layers[i]) != null)
                MediaSlot(
                  label: 'Layer ${i + 1} — ${layers[i]['role'] ?? layers[i]['id'] ?? ''}',
                  path: sourceOf(layers[i]),
                  manifest: manifest,
                  size: 120,
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Layer ${i + 1} — ${layers[i]['type']} (no image, e.g. particles/gradient)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (layers[i] is Map && (layers[i] as Map)['video'] != null)
                MediaSlot(
                  label: 'Layer ${i + 1} — video',
                  path: (layers[i] as Map)['video'] as String?,
                  manifest: manifest,
                  size: 120,
                ),
            ],
            const SizedBox(height: 20),
          ],
          if (events.isNotEmpty) ...[
            Text('Event heroes', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final e in events)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: e['hero'] != null
                    ? MediaSlot(
                        label: (e['title'] as Map?)?['en'] as String? ?? e['id'] as String? ?? '',
                        path: sourceOf(e['hero']),
                        manifest: manifest,
                        size: 120,
                      )
                    : Text(
                        '${(e['title'] as Map?)?['en'] ?? e['id']} — no hero image',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
              ),
          ],
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

  Future<void> _confirmDelete() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete era'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This permanently removes content/eras/${widget.slug}.json and its '
                'index.json entry. Type the slug to confirm:'),
            const SizedBox(height: 12),
            TextField(controller: controller, decoration: InputDecoration(hintText: widget.slug)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, controller.text.trim() == widget.slug),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (confirmed != true) return;
    ref.read(contentDraftProvider.notifier).deleteEra(widget.slug);
    if (mounted) context.go('/eras');
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
