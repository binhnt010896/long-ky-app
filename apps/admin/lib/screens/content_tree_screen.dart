import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/content_draft.dart';
import '../util/media_urls.dart';
import '../util/slug.dart';
import '../widgets/citation_field.dart';
import '../widgets/hex_color_field.dart';
import '../widgets/localized_text_field.dart';
import '../widgets/media_slot.dart';
import '../widgets/year_range_field.dart';

/// Periods (in `order`) with their eras nested (in `order`), replacing the
/// old flat Eras list. Selecting a period opens its field form here;
/// selecting an era navigates to the existing [EraEditorScreen] at
/// `/eras/:slug` — reordering/moving is done from the row controls, not
/// drag-and-drop (see EXECUTION.md's Cycle H scope note).
class ContentTreeScreen extends ConsumerStatefulWidget {
  const ContentTreeScreen({super.key});

  @override
  ConsumerState<ContentTreeScreen> createState() => _ContentTreeScreenState();
}

class _ContentTreeScreenState extends ConsumerState<ContentTreeScreen> {
  String? _selectedPeriodId;

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(contentDraftProvider);

    return draft.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Failed to load: $e')),
      data: (draft) {
        final result = draft.validate();
        final issuesByFile = <String, int>{};
        for (final issue in result.issues) {
          issuesByFile[issue.file] = (issuesByFile[issue.file] ?? 0) + 1;
        }

        final periods = draft.periods.toList()
          ..sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));
        final erasByPeriod = <String, List<MapEntry<String, Map<String, dynamic>>>>{};
        for (final entry in draft.eraFiles.entries) {
          try {
            final era = jsonDecode(entry.value) as Map<String, dynamic>;
            final slug = entry.key.replaceAll('.json', '');
            (erasByPeriod[era['period'] as String] ??= []).add(MapEntry(slug, era));
          } catch (_) {
            // Skip an era whose draft text isn't valid JSON right now.
          }
        }
        for (final list in erasByPeriod.values) {
          list.sort(
            (a, b) => (a.value['order'] as int).compareTo(b.value['order'] as int),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 420,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Content', style: Theme.of(context).textTheme.headlineSmall),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Add period',
                          icon: const Icon(Icons.add_box_outlined),
                          onPressed: () => _addPeriod(context),
                        ),
                      ],
                    ),
                    Expanded(
                      child: ListView(
                        children: [
                          for (var i = 0; i < periods.length; i++)
                            _PeriodTile(
                              period: periods[i],
                              index: i,
                              periodCount: periods.length,
                              eras: erasByPeriod[periods[i]['id']] ?? const [],
                              allPeriods: periods,
                              selected: _selectedPeriodId == periods[i]['id'],
                              issuesByFile: issuesByFile,
                              onSelect: () =>
                                  setState(() => _selectedPeriodId = periods[i]['id'] as String),
                              onAddEra: () => _addEra(context, periods[i]['id'] as String),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: _selectedPeriodId == null
                  ? const Center(child: Text('Select a period to edit it.'))
                  : _PeriodDetailPane(
                      key: ValueKey(_selectedPeriodId),
                      periodId: _selectedPeriodId!,
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addPeriod(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _NewPeriodDialog(),
    );
    if (result == null) return;
    ref.read(contentDraftProvider.notifier).addPeriod(result);
    setState(() => _selectedPeriodId = result['id'] as String);
  }

  Future<void> _addEra(BuildContext context, String periodId) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _NewEraDialog(periodId: periodId),
    );
    if (result == null) return;
    ref.read(contentDraftProvider.notifier).addEra(result);
    if (context.mounted) context.go('/eras/${result['slug']}');
  }
}

class _PeriodTile extends ConsumerWidget {
  const _PeriodTile({
    required this.period,
    required this.index,
    required this.periodCount,
    required this.eras,
    required this.allPeriods,
    required this.selected,
    required this.issuesByFile,
    required this.onSelect,
    required this.onAddEra,
  });

  final Map<String, dynamic> period;
  final int index;
  final int periodCount;
  final List<MapEntry<String, Map<String, dynamic>>> eras;
  final List<Map<String, dynamic>> allPeriods;
  final bool selected;
  final Map<String, int> issuesByFile;
  final VoidCallback onSelect;
  final VoidCallback onAddEra;

  String _title(Map<String, dynamic> m) =>
      (m['title'] as Map?)?['en'] as String? ?? (m['title'] as Map?)?['vi'] as String? ?? m['id'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: selected ? Theme.of(context).colorScheme.secondaryContainer : null,
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            onTap: onSelect,
            title: Text(_title(period)),
            subtitle: Text('${period['id']} · ${eras.length} era(s)'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  onPressed: index == 0
                      ? null
                      : () => ref
                            .read(contentDraftProvider.notifier)
                            .reorderPeriod(period['id'] as String, index - 1),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  onPressed: index == periodCount - 1
                      ? null
                      : () => ref
                            .read(contentDraftProvider.notifier)
                            .reorderPeriod(period['id'] as String, index + 1),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  tooltip: 'Add era to ${_title(period)}',
                  onPressed: onAddEra,
                ),
              ],
            ),
          ),
          for (var i = 0; i < eras.length; i++)
            _EraRow(
              slug: eras[i].key,
              era: eras[i].value,
              index: i,
              eraCount: eras.length,
              allPeriods: allPeriods,
              issueCount: issuesByFile['${eras[i].key}.json'] ?? 0,
            ),
        ],
      ),
    );
  }
}

class _EraRow extends ConsumerWidget {
  const _EraRow({
    required this.slug,
    required this.era,
    required this.index,
    required this.eraCount,
    required this.allPeriods,
    required this.issueCount,
  });

  final String slug;
  final Map<String, dynamic> era;
  final int index;
  final int eraCount;
  final List<Map<String, dynamic>> allPeriods;
  final int issueCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = (era['title'] as Map?)?['en'] as String? ?? (era['title'] as Map?)?['vi'] as String? ?? slug;
    final isDraft = era['draft'] == true;

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 8),
      child: ListTile(
        dense: true,
        onTap: () => context.go('/eras/$slug'),
        title: Text(title),
        subtitle: Text(slug),
        leading: isDraft ? const Icon(Icons.edit_note, size: 18) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (issueCount > 0)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Chip(
                  label: Text('$issueCount'),
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            IconButton(
              icon: const Icon(Icons.arrow_upward, size: 16),
              onPressed: index == 0
                  ? null
                  : () => ref.read(contentDraftProvider.notifier).nudgeEraOrder(slug, up: true),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_downward, size: 16),
              onPressed: index == eraCount - 1
                  ? null
                  : () => ref.read(contentDraftProvider.notifier).nudgeEraOrder(slug, up: false),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.drive_file_move_outline, size: 16),
              tooltip: 'Move to period',
              onSelected: (periodId) =>
                  ref.read(contentDraftProvider.notifier).moveEraToPeriod(slug, periodId),
              itemBuilder: (context) => [
                for (final p in allPeriods)
                  PopupMenuItem(
                    value: p['id'] as String,
                    child: Text((p['title'] as Map?)?['en'] as String? ?? p['id']),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodDetailPane extends ConsumerStatefulWidget {
  const _PeriodDetailPane({required this.periodId, super.key});

  final String periodId;

  @override
  ConsumerState<_PeriodDetailPane> createState() => _PeriodDetailPaneState();
}

class _PeriodDetailPaneState extends ConsumerState<_PeriodDetailPane> {
  late final titleVi = TextEditingController();
  late final titleEn = TextEditingController();
  late final kickerVi = TextEditingController();
  late final kickerEn = TextEditingController();
  late final subtitleVi = TextEditingController();
  late final subtitleEn = TextEditingController();
  Map<String, dynamic>? _yearRange;
  String _accent = '#5f8f74';
  bool _seeded = false;

  void _seed(Map<String, dynamic> period) {
    titleVi.text = (period['title'] as Map?)?['vi'] as String? ?? '';
    titleEn.text = (period['title'] as Map?)?['en'] as String? ?? '';
    kickerVi.text = (period['kicker'] as Map?)?['vi'] as String? ?? '';
    kickerEn.text = (period['kicker'] as Map?)?['en'] as String? ?? '';
    subtitleVi.text = (period['subtitle'] as Map?)?['vi'] as String? ?? '';
    subtitleEn.text = (period['subtitle'] as Map?)?['en'] as String? ?? '';
    _yearRange = (period['yearRange'] as Map?)?.cast<String, dynamic>();
    _accent = (period['accent'] as String?) ?? '#5f8f74';
    _seeded = true;
  }

  void _save() {
    ref.read(contentDraftProvider.notifier).updatePeriod(widget.periodId, (period) {
      period['title'] = localizedValue(titleVi, titleEn);
      period['kicker'] = localizedValue(kickerVi, kickerEn);
      period['subtitle'] = localizedValue(subtitleVi, subtitleEn);
      if (_yearRange != null) period['yearRange'] = _yearRange;
      period['accent'] = _accent;
      return period;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Staged — commit from Publish to save for real.')),
    );
  }

  Future<void> _delete() async {
    final draft = ref.read(contentDraftProvider).requireValue;
    final eras = draft.erasInPeriod(widget.periodId);
    if (eras.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Can\'t delete this period'),
          content: Text('Move or delete these eras first: ${eras.join(', ')}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete period'),
        content: const Text('This period has no eras. Delete it?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(contentDraftProvider.notifier).deletePeriod(widget.periodId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(contentDraftProvider).valueOrNull;
    if (draft == null) return const SizedBox();
    final period = draft.periods.firstWhere((p) => p['id'] == widget.periodId, orElse: () => {});
    if (period.isEmpty) return const Center(child: Text('Period was removed.'));
    if (!_seeded) _seed(period);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(widget.periodId, style: Theme.of(context).textTheme.headlineSmall),
                const Spacer(),
                IconButton(
                  tooltip: 'Delete period',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _delete,
                ),
              ],
            ),
            const SizedBox(height: 16),
            LocalizedTextField(label: 'Title', vi: titleVi, en: titleEn),
            LocalizedTextField(label: 'Kicker', vi: kickerVi, en: kickerEn),
            LocalizedTextField(label: 'Subtitle', vi: subtitleVi, en: subtitleEn),
            const SizedBox(height: 8),
            YearRangeField(
              initial: _yearRange,
              onChanged: (v) => _yearRange = v,
            ),
            const SizedBox(height: 8),
            HexColorField(
              label: 'Accent',
              initial: _accent,
              onChanged: (v) => _accent = v,
            ),
            const SizedBox(height: 16),
            MediaSlot(
              label: 'Cover',
              path: _coverSource(period['cover']),
              manifest: MediaManifest.fromJson(draft.files['content/media-manifest.json']!),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('Stage changes')),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final c in [titleVi, titleEn, kickerVi, kickerEn, subtitleVi, subtitleEn]) {
      c.dispose();
    }
    super.dispose();
  }
}

class _NewPeriodDialog extends StatefulWidget {
  const _NewPeriodDialog();

  @override
  State<_NewPeriodDialog> createState() => _NewPeriodDialogState();
}

class _NewPeriodDialogState extends State<_NewPeriodDialog> {
  final titleVi = TextEditingController();
  final titleEn = TextEditingController();
  final kickerVi = TextEditingController();
  final kickerEn = TextEditingController();
  final idController = TextEditingController();
  bool _idEdited = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New period'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LocalizedTextField(
                label: 'Title',
                vi: titleVi..addListener(_suggestId),
                en: titleEn,
              ),
              LocalizedTextField(label: 'Kicker', vi: kickerVi, en: kickerEn),
              TextField(
                controller: idController,
                onChanged: (_) => _idEdited = true,
                decoration: const InputDecoration(labelText: 'id (locked once created)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _create, child: const Text('Create')),
      ],
    );
  }

  void _suggestId() {
    if (_idEdited) return;
    idController.text = _slugFrom(titleVi.text);
  }

  void _create() {
    if (idController.text.trim().isEmpty || titleVi.text.trim().isEmpty) return;
    Navigator.pop(context, <String, dynamic>{
      'id': idController.text.trim(),
      'title': localizedValue(titleVi, titleEn),
      'kicker': localizedValue(kickerVi, kickerEn),
      'yearRange': {
        'display': {'vi': '', 'en': ''},
      },
      'accent': '#5f8f74',
    });
  }
}

class _NewEraDialog extends StatefulWidget {
  const _NewEraDialog({required this.periodId});
  final String periodId;

  @override
  State<_NewEraDialog> createState() => _NewEraDialogState();
}

class _NewEraDialogState extends State<_NewEraDialog> {
  final titleVi = TextEditingController();
  final titleEn = TextEditingController();
  final kickerVi = TextEditingController();
  final kickerEn = TextEditingController();
  final subtitleVi = TextEditingController();
  final subtitleEn = TextEditingController();
  final slugController = TextEditingController();
  Map<String, dynamic>? _citation;
  String _accent = '#5f8f74';
  bool _slugEdited = false;
  bool _draft = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('New era in ${widget.periodId}'),
      content: SizedBox(
        width: 520,
        height: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LocalizedTextField(
                label: 'Title',
                vi: titleVi..addListener(_suggestSlug),
                en: titleEn,
              ),
              LocalizedTextField(label: 'Kicker', vi: kickerVi, en: kickerEn),
              LocalizedTextField(label: 'Subtitle', vi: subtitleVi, en: subtitleEn),
              TextField(
                controller: slugController,
                onChanged: (_) => _slugEdited = true,
                decoration: const InputDecoration(labelText: 'slug (locked once created)'),
              ),
              const SizedBox(height: 8),
              HexColorField(label: 'Accent', initial: _accent, onChanged: (v) => _accent = v),
              const SizedBox(height: 8),
              CitationField(label: 'Primary source', initial: null, onChanged: (v) => _citation = v),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _draft,
                title: const Text('Create as draft'),
                subtitle: const Text('Recommended — keeps it off the next publish until ready.'),
                onChanged: (v) => setState(() => _draft = v ?? true),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _create, child: const Text('Create')),
      ],
    );
  }

  void _suggestSlug() {
    if (_slugEdited) return;
    slugController.text = _slugFrom(titleVi.text);
  }

  void _create() {
    final slug = slugController.text.trim();
    final work = _citation?['work'] as String?;
    if (slug.isEmpty || titleVi.text.trim().isEmpty || work == null || work.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Slug, title (vi) and primary source work are required.')));
      return;
    }
    final era = <String, dynamic>{
      'schemaVersion': 1,
      'id': slug,
      'slug': slug,
      'period': widget.periodId,
      'title': localizedValue(titleVi, titleEn),
      'kicker': localizedValue(kickerVi, kickerEn),
      'subtitle': localizedValue(subtitleVi, subtitleEn),
      'yearRange': {
        'display': {'vi': '', 'en': ''},
        'startYear': 0,
        'endYear': 0,
      },
      'palette': {'accent': _accent},
      'primarySource': _citation,
      'events': [
        {
          'id': '$slug-event-1',
          'order': 0,
          'kind': 'historical',
          'year': {
            'display': {'vi': '', 'en': ''},
          },
          'title': {'vi': 'Sự kiện mới', 'en': 'New event'},
          'summary': {'vi': 'Chỉnh sửa sự kiện này', 'en': 'Edit this event'},
          'citation': _citation,
        },
      ],
      if (_draft) 'draft': true,
    };
    Navigator.pop(context, era);
  }
}

String _slugFrom(String text) => slugify(text);

String? _coverSource(Object? assetRef) {
  if (assetRef is! Map) return null;
  return (assetRef['flagship'] as String?) ?? (assetRef['reduced'] as String?);
}
