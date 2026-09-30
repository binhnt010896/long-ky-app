import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/content_draft.dart';
import '../widgets/event_delete_dialog.dart';
import '../widgets/event_dialog.dart';

/// Every event in one list (Cycle N) — the registry, `content/events.json`.
/// Filter by era, by "standalone" (events no era lists), or by text; create a
/// standalone event; edit one; move it into an era or out of one (it then
/// becomes standalone — never deleted); or delete it for good, with every
/// reference cleaned up.
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

/// Filter values: [_all], [_standalone], or an era slug.
const String _all = '*';
const String _standalone = '~standalone';

class _EventsScreenState extends ConsumerState<EventsScreen> {
  String _scope = _all;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final draftAsync = ref.watch(contentDraftProvider);
    return draftAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Failed to load: $e')),
      data: _buildLoaded,
    );
  }

  Widget _buildLoaded(ContentDraft draft) {
    final eraOf = <String, String>{
      for (final entry in draft.eventIdsByEra.entries)
        for (final id in entry.value) id: entry.key,
    };
    final eraSlugs = draft.eventIdsByEra.keys.toList()..sort();
    final standaloneCount = draft.standaloneEvents.length;

    final q = _query.trim().toLowerCase();
    final shown = [
      for (final e in draft.events)
        if (_scope == _all ||
            (_scope == _standalone ? !eraOf.containsKey(e['id']) : eraOf[e['id']] == _scope))
          if (q.isEmpty || _haystack(e).contains(q)) e,
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Events (${draft.events.length} · $standaloneCount standalone)',
                  style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => const EventDialog(eraSlug: null),
                ),
                icon: const Icon(Icons.add),
                label: const Text('New standalone event'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'An event lives here once; an era lists the ones it contains. An event no era '
            'lists is a standalone event.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<String>(
                  initialValue: _scope,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Show', isDense: true),
                  items: [
                    const DropdownMenuItem(value: _all, child: Text('All events')),
                    DropdownMenuItem(
                      value: _standalone,
                      child: Text('Standalone only ($standaloneCount)'),
                    ),
                    for (final slug in eraSlugs)
                      DropdownMenuItem(value: slug, child: Text('Era: $slug')),
                  ],
                  onChanged: (v) => setState(() => _scope = v ?? _all),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search, size: 18),
                    hintText: 'Search title, id or year…',
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: shown.isEmpty
                ? const Center(child: Text('No events match.'))
                : ListView.builder(
                    itemCount: shown.length,
                    itemBuilder: (context, i) =>
                        _row(draft, shown[i], eraOf[shown[i]['id']], eraSlugs),
                  ),
          ),
        ],
      ),
    );
  }

  static String _haystack(Map<String, dynamic> e) {
    final t = e['title'] as Map?;
    final y = (e['year'] as Map?)?['display'] as Map?;
    return '${t?['vi'] ?? ''} ${t?['en'] ?? ''} ${e['id']} ${y?['vi'] ?? ''}'.toLowerCase();
  }

  Widget _row(ContentDraft draft, Map<String, dynamic> e, String? era, List<String> eraSlugs) {
    final id = e['id'] as String;
    final title = (e['title'] as Map?)?['vi'] as String? ?? id;
    final year = ((e['year'] as Map?)?['display'] as Map?)?['vi'] ?? '';
    final standalone = era == null;
    final eraCount = era == null ? 0 : (draft.eventIdsByEra[era]?.length ?? 0);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text('$year · ${e['kind']} · $id'),
        leading: Chip(
          label: Text(standalone ? 'Standalone' : era),
          backgroundColor: standalone ? scheme.tertiaryContainer : null,
          visualDensity: VisualDensity.compact,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => EventDialog(eraSlug: era, eventId: id, initial: e),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: standalone ? 'Add to an era' : 'Move to another era',
              icon: const Icon(Icons.drive_file_move_outline),
              onSelected: (slug) => _move(id, slug),
              itemBuilder: (context) => [
                for (final slug in eraSlugs)
                  if (slug != era) PopupMenuItem(value: slug, child: Text(slug)),
              ],
            ),
            IconButton(
              tooltip: standalone
                  ? 'Already standalone'
                  : eraCount <= 1
                      ? 'An era keeps at least one event'
                      : 'Remove from era (it becomes a standalone event)',
              icon: const Icon(Icons.link_off),
              onPressed: standalone || eraCount <= 1 ? null : () => _remove(id, title),
            ),
            IconButton(
              tooltip: 'Delete permanently',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => confirmAndDeleteEvent(context, ref, eventId: id, title: title),
            ),
          ],
        ),
      ),
    );
  }

  void _move(String eventId, String slug) {
    try {
      ref.read(contentDraftProvider.notifier).moveEventToEra(eventId, slug);
    } on StateError catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _remove(String eventId, String title) {
    try {
      ref.read(contentDraftProvider.notifier).removeEventFromEra(eventId);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('"$title" is now a standalone event (it needs a dated year and a hero image).'),
      ));
    } on StateError catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
