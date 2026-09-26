import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/content_draft.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(contentDraftProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: draft.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => _LoadError(error: e),
        data: (draft) {
          final result = draft.validate();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dashboard', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _CountCard(label: 'Eras', count: result.eraCount, onTap: () => context.go('/eras')),
                  _CountCard(
                    label: 'People',
                    count: result.peopleCount,
                    onTap: () => context.go('/people'),
                  ),
                  _CountCard(
                    label: 'Periods',
                    count: result.periodCount,
                    onTap: () => context.go('/periods'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        result.isValid ? Icons.check_circle : Icons.error,
                        color: result.isValid ? Colors.green : Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          result.isValid
                              ? 'All loaded content is valid.'
                              : '${result.issues.length} validation issue(s) — see the era/people/periods editors.',
                        ),
                      ),
                      if (draft.isDirty)
                        Chip(label: Text('${draft.pendingChanges.length} unsaved change(s)')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => context.go('/publish'),
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Go to Publish'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.label, required this.count, required this.onTap});

  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$count', style: Theme.of(context).textTheme.headlineMedium),
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadError extends ConsumerWidget {
  const _LoadError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Failed to load content: $error'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => ref.read(contentDraftProvider.notifier).reload(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
