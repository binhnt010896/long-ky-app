import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/content_draft.dart';
import 'raw_json_file_editor.dart';

/// Edits the shared `content/people.json` registry. There's no
/// photo-verified field in the schema (and G-4's plan is deliberately not
/// to add one — see EXECUTION.md) so the "confirm this portrait matches
/// the real photo" step is CMS-only: an expandable checklist that reminds
/// the admin, not data written to the file.
class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  final _confirmed = <String>{};

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(contentDraftProvider).valueOrNull;
    final withPortraits = <String>[];
    if (draft != null) {
      try {
        final decoded = jsonDecode(draft.peopleJson) as Map<String, dynamic>;
        for (final p in decoded['people'] as List) {
          final person = p as Map<String, dynamic>;
          if (person['portrait'] != null) {
            final name = (person['name'] as Map?)?['en'] as String? ?? person['id'] as String;
            withPortraits.add('${person['id']}\t$name');
          }
        }
      } catch (_) {
        // Draft text isn't valid JSON right now — skip the checklist.
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (withPortraits.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: ExpansionTile(
              title: Text(
                'Photo fidelity check (${_confirmed.length}/${withPortraits.length} confirmed) — '
                'camera-era figures must match their real photo (defamation risk).',
              ),
              children: [
                for (final entry in withPortraits)
                  CheckboxListTile(
                    value: _confirmed.contains(entry.split('\t').first),
                    title: Text(entry.split('\t').last),
                    onChanged: (v) => setState(() {
                      final id = entry.split('\t').first;
                      if (v == true) {
                        _confirmed.add(id);
                      } else {
                        _confirmed.remove(id);
                      }
                    }),
                  ),
              ],
            ),
          ),
        const Expanded(
          child: RawJsonFileEditor(path: 'content/people.json', title: 'People registry'),
        ),
      ],
    );
  }
}
