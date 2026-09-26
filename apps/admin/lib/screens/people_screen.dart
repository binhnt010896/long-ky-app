import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/content_draft.dart';
import '../util/media_urls.dart';
import '../util/slug.dart';
import '../util/person_asset_path.dart';
import '../widgets/localized_text_field.dart';
import '../widgets/media_replace_dialog.dart';
import '../widgets/media_slot.dart';

/// Field-by-field editor for the shared `content/people.json` registry
/// (154 people). A search list on the left, a form on the right — see
/// EXECUTION.md's Cycle H (H-2).
class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  String? _selectedId;
  String _query = '';
  bool _onlyMissingPortrait = false;
  bool _onlyUnused = false;

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(contentDraftProvider);

    return draft.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Failed to load: $e')),
      data: (draft) {
        var people = draft.people.toList()
          ..sort((a, b) => ((a['name'] as Map?)?['en'] as String? ?? '').compareTo(
            (b['name'] as Map?)?['en'] as String? ?? '',
          ));

        if (_query.trim().isNotEmpty) {
          final q = _query.toLowerCase();
          people = people.where((p) {
            final name = '${(p['name'] as Map?)?['vi']} ${(p['name'] as Map?)?['en']} ${p['id']}';
            return name.toLowerCase().contains(q);
          }).toList();
        }
        if (_onlyMissingPortrait) {
          people = people.where((p) => p['portrait'] == null).toList();
        }
        if (_onlyUnused) {
          people = people
              .where((p) => draft.erasReferencingPerson(p['id'] as String).isEmpty)
              .toList();
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 380,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('People (${draft.people.length})', style: Theme.of(context).textTheme.headlineSmall),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Add person',
                          icon: const Icon(Icons.person_add_alt_1_outlined),
                          onPressed: () => _addPerson(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search name or id',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('Missing portrait'),
                          selected: _onlyMissingPortrait,
                          onSelected: (v) => setState(() => _onlyMissingPortrait = v),
                        ),
                        FilterChip(
                          label: const Text('Unused'),
                          selected: _onlyUnused,
                          onSelected: (v) => setState(() => _onlyUnused = v),
                        ),
                      ],
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: people.length,
                        itemBuilder: (context, i) {
                          final p = people[i];
                          final id = p['id'] as String;
                          return ListTile(
                            selected: _selectedId == id,
                            title: Text((p['name'] as Map?)?['en'] as String? ?? id),
                            subtitle: Text(id),
                            onTap: () => setState(() => _selectedId = id),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: _selectedId == null
                  ? const Center(child: Text('Select a person to edit.'))
                  : _PersonDetailPane(key: ValueKey(_selectedId), personId: _selectedId!),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addPerson(BuildContext context) async {
    final nameVi = TextEditingController();
    final idController = TextEditingController();
    var idEdited = false;
    nameVi.addListener(() {
      if (!idEdited) idController.text = slugify(nameVi.text);
    });

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New person'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameVi,
              decoration: const InputDecoration(labelText: 'Name (vi)'),
            ),
            TextField(
              controller: idController,
              onChanged: (_) => idEdited = true,
              decoration: const InputDecoration(labelText: 'id (locked once created)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
        ],
      ),
    );

    if (result != true || idController.text.trim().isEmpty || nameVi.text.trim().isEmpty) return;
    ref.read(contentDraftProvider.notifier).addPerson({
      'id': idController.text.trim(),
      'name': {'vi': nameVi.text.trim(), 'en': nameVi.text.trim()},
    });
    setState(() => _selectedId = idController.text.trim());
  }
}

class _PersonDetailPane extends ConsumerStatefulWidget {
  const _PersonDetailPane({required this.personId, super.key});
  final String personId;

  @override
  ConsumerState<_PersonDetailPane> createState() => _PersonDetailPaneState();
}

class _PersonDetailPaneState extends ConsumerState<_PersonDetailPane> {
  late final nameVi = TextEditingController();
  late final nameEn = TextEditingController();
  late final epithetVi = TextEditingController();
  late final epithetEn = TextEditingController();
  late final bioVi = TextEditingController();
  late final bioEn = TextEditingController();
  bool _seeded = false;
  bool _photoConfirmed = false;

  void _seed(Map<String, dynamic> person) {
    nameVi.text = (person['name'] as Map?)?['vi'] as String? ?? '';
    nameEn.text = (person['name'] as Map?)?['en'] as String? ?? '';
    epithetVi.text = (person['epithet'] as Map?)?['vi'] as String? ?? '';
    epithetEn.text = (person['epithet'] as Map?)?['en'] as String? ?? '';
    bioVi.text = (person['bio'] as Map?)?['vi'] as String? ?? '';
    bioEn.text = (person['bio'] as Map?)?['en'] as String? ?? '';
    _seeded = true;
  }

  void _save() {
    ref.read(contentDraftProvider.notifier).updatePerson(widget.personId, (person) {
      person['name'] = localizedValue(nameVi, nameEn);
      if (epithetVi.text.isNotEmpty || epithetEn.text.isNotEmpty) {
        person['epithet'] = localizedValue(epithetVi, epithetEn);
      } else {
        person.remove('epithet');
      }
      if (bioVi.text.isNotEmpty || bioEn.text.isNotEmpty) {
        person['bio'] = localizedValue(bioVi, bioEn);
      } else {
        person.remove('bio');
      }
      return person;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Staged — commit from Publish to save for real.')));
  }

  Future<void> _delete(List<String> usedIn) async {
    if (usedIn.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Can't delete this person"),
          content: Text('Still referenced by: ${usedIn.join(', ')}'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete person'),
        content: Text('Delete ${widget.personId}? Not referenced by any era.'),
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
      ref.read(contentDraftProvider.notifier).deletePerson(widget.personId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(contentDraftProvider).valueOrNull;
    if (draft == null) return const SizedBox();
    final person = draft.people.firstWhere((p) => p['id'] == widget.personId, orElse: () => {});
    if (person.isEmpty) return const Center(child: Text('Person was removed.'));
    if (!_seeded) _seed(person);

    final manifest = MediaManifest.fromJson(draft.files['content/media-manifest.json']!);
    final usedIn = draft.erasReferencingPerson(widget.personId);
    final hasPhoto = person['portrait'] != null || person['avatar'] != null || person['fullBody'] != null;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(widget.personId, style: Theme.of(context).textTheme.headlineSmall),
                const Spacer(),
                IconButton(
                  tooltip: 'Delete person',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(usedIn),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LocalizedTextField(label: 'Name', vi: nameVi, en: nameEn),
            LocalizedTextField(label: 'Epithet', vi: epithetVi, en: epithetEn),
            LocalizedTextField(label: 'Bio', vi: bioVi, en: bioEn, maxLines: 6),
            const SizedBox(height: 8),
            _PersonImageSlot(
              label: 'Avatar',
              field: 'avatar',
              suffix: 'avatar',
              person: person,
              usedIn: usedIn,
              manifest: manifest,
            ),
            _PersonImageSlot(
              label: 'Full body',
              field: 'fullBody',
              suffix: 'full',
              person: person,
              usedIn: usedIn,
              manifest: manifest,
            ),
            if (person['portrait'] != null)
              MediaSlot(
                label: 'Portrait',
                path: _sourcePath(person['portrait']),
                manifest: manifest,
                caption: person['avatar'] != null || person['fullBody'] != null
                    ? 'Legacy — not shown while Avatar/Full body are set.'
                    : "Legacy 3-part sheet — the app crops this era's figures "
                          'from it since there is no dedicated Avatar/Full body yet.',
              ),
            if (hasPhoto) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _photoConfirmed,
                title: const Text('Photo fidelity confirmed'),
                subtitle: const Text(
                  'CMS-only reminder, not saved to the file — a photographed-era '
                  "figure's portrait must match their real photo.",
                ),
                onChanged: (v) => setState(() => _photoConfirmed = v ?? false),
              ),
            ],
            const SizedBox(height: 8),
            Text('Used in', style: Theme.of(context).textTheme.labelLarge),
            if (usedIn.isEmpty)
              const Text('No era currently references this person.')
            else
              Wrap(spacing: 8, children: [for (final slug in usedIn) Chip(label: Text(slug))]),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('Stage changes')),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final c in [nameVi, nameEn, epithetVi, epithetEn, bioVi, bioEn]) {
      c.dispose();
    }
    super.dispose();
  }
}

String? _sourcePath(Object? assetRef) {
  if (assetRef is! Map) return null;
  return (assetRef['flagship'] as String?) ?? (assetRef['reduced'] as String?);
}

/// Avatar/full body, with an "Add…" action when the person has neither yet
/// (Cycle I's I-3) — creates the asset ref at the conventional path, then
/// opens the same upload dialog a MediaSlot's own Replace button would.
class _PersonImageSlot extends ConsumerWidget {
  const _PersonImageSlot({
    required this.label,
    required this.field,
    required this.suffix,
    required this.person,
    required this.usedIn,
    required this.manifest,
  });

  final String label;
  final String field; // 'avatar' or 'fullBody'
  final String suffix; // 'avatar' or 'full' — the filename suffix
  final Map<String, dynamic> person;
  final List<String> usedIn;
  final MediaManifest manifest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetRef = person[field] as Map<String, dynamic>?;
    if (assetRef != null) {
      return MediaSlot(label: label, path: _sourcePath(assetRef), manifest: manifest);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: Theme.of(context).textTheme.labelLarge)),
          OutlinedButton.icon(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text('Add $label'),
            onPressed: () => _add(context, ref),
          ),
        ],
      ),
    );
  }

  void _add(BuildContext context, WidgetRef ref) {
    final id = person['id'] as String;
    final path = personAssetPath(id: id, usedIn: usedIn, suffix: suffix);
    ref.read(contentDraftProvider.notifier).updatePerson(id, (p) {
      p[field] = {'id': '$id-$suffix', 'type': 'image', 'flagship': path, 'reduced': path};
      return p;
    });
    showDialog<void>(
      context: context,
      builder: (context) => MediaReplaceDialog(path: path, manifest: manifest),
    );
  }
}
