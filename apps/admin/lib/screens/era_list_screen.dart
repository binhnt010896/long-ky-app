import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/content_draft.dart';

class EraListScreen extends ConsumerWidget {
  const EraListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        final entries = draft.eraFiles.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Eras (${entries.length})', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final filename = entries[i].key;
                    final slug = filename.replaceAll('.json', '');
                    String title = slug;
                    try {
                      final decoded = jsonDecode(entries[i].value) as Map<String, dynamic>;
                      final t = decoded['title'] as Map<String, dynamic>?;
                      title = (t?['en'] as String?) ?? (t?['vi'] as String?) ?? slug;
                    } catch (_) {
                      // Unparseable draft text — fall back to the slug.
                    }
                    final issueCount = issuesByFile[filename] ?? 0;
                    return ListTile(
                      title: Text(title),
                      subtitle: Text(filename),
                      trailing: issueCount > 0
                          ? Chip(
                              label: Text('$issueCount issue(s)'),
                              backgroundColor: Theme.of(context).colorScheme.errorContainer,
                            )
                          : null,
                      onTap: () => context.go('/eras/$slug'),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
