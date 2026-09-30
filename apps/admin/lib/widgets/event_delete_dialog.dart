import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/content_draft.dart';

/// Confirms and performs a permanent event delete, listing exactly what else
/// changes: the era that loses it, the events whose "Related events" drop it,
/// and the street-map streets that name it. Shared by the era editor's Events
/// tab and the Events screen, so the two can never disagree about what a delete
/// touches. The admin must type the id to confirm — an event id is public.
Future<void> confirmAndDeleteEvent(
  BuildContext context,
  WidgetRef ref, {
  required String eventId,
  required String title,
}) async {
  final draft = ref.read(contentDraftProvider).valueOrNull;
  if (draft == null) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => _DeleteEventDialog(
      eventId: eventId,
      title: title,
      refs: draft.referencesTo(eventId),
    ),
  );
  if (confirmed != true) return;
  ref.read(contentDraftProvider.notifier).deleteEvent(eventId);
}

/// Owns its own text controller: disposing one from the caller right after
/// `showDialog` returns races the dialog's closing animation, which is still
/// building the field.
class _DeleteEventDialog extends StatefulWidget {
  const _DeleteEventDialog({required this.eventId, required this.title, required this.refs});

  final String eventId;
  final String title;
  final EventReferences refs;

  @override
  State<_DeleteEventDialog> createState() => _DeleteEventDialogState();
}

class _DeleteEventDialogState extends State<_DeleteEventDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final err = TextStyle(color: Theme.of(context).colorScheme.error);
    final refs = widget.refs;
    return AlertDialog(
      title: Text('Delete "${widget.title}"'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This permanently removes event "${widget.eventId}". '
              'To keep it, use "Remove from era" instead — it becomes a standalone event.'),
          if (refs.eraSlug != null) ...[
            const SizedBox(height: 8),
            Text('Removed from era: ${refs.eraSlug}', style: err),
          ],
          if (refs.relatedFrom.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Also removed from "Related events" on: ${refs.relatedFrom.join(', ')}',
                style: err),
          ],
          for (final s in refs.streets) ...[
            const SizedBox(height: 8),
            Text(
              s.losesLastTarget
                  ? 'Street "${s.name}" names only this event — the street is removed too.'
                  : 'Street "${s.name}" loses this as one of its targets.',
              style: err,
            ),
          ],
          const SizedBox(height: 12),
          const Text('Type the id to confirm:'),
          const SizedBox(height: 8),
          TextField(controller: _controller, decoration: InputDecoration(hintText: widget.eventId)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: () => Navigator.pop(context, _controller.text.trim() == widget.eventId),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
