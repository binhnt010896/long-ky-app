import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../api/api_providers.dart';
import '../api/cms_api_client.dart';
import '../state/content_draft.dart';

/// Commit → dry run → publish, in that order. A real publish is gated on
/// a clean dry run in [tool/publish_content.sh] itself; this screen just
/// mirrors that order so the admin doesn't skip a step by accident.
class PublishScreen extends ConsumerStatefulWidget {
  const PublishScreen({super.key});

  @override
  ConsumerState<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends ConsumerState<PublishScreen> {
  final _messageController = TextEditingController(text: 'content: edit via CMS');
  bool _busy = false;
  String? _status;
  PublishRunStatus? _lastRun;
  Timer? _pollTimer;

  Future<void> _commit() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await ref.read(contentDraftProvider.notifier).commit(_messageController.text.trim());
      setState(() => _status = 'Committed to main.');
    } on CommitConflictException catch (e) {
      setState(() => _status = '${e.message} — reload the draft and redo your edit.');
    } catch (e) {
      setState(() => _status = 'Commit failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _triggerPublish({required bool dryRun}) async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await ref.read(cmsApiClientProvider).publish(dryRun: dryRun);
      setState(() => _status = '${dryRun ? "Dry run" : "Publish"} triggered — polling status…');
      _startPolling();
    } catch (e) {
      setState(() => _status = 'Trigger failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _refreshStatus());
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    try {
      final run = await ref.read(cmsApiClientProvider).publishStatus();
      setState(() => _lastRun = run);
      if (run != null && !run.isRunning) {
        _pollTimer?.cancel();
      }
    } catch (_) {
      // Keep polling — a transient GitHub API hiccup shouldn't stop the loop.
    }
  }

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(contentDraftProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: draft.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Failed to load: $e')),
        data: (draft) {
          final result = draft.validate();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Publish', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('1. Commit staged edits', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (draft.pendingChanges.isEmpty)
                        const Text('No staged changes.')
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final entry in draft.pendingChanges.entries)
                              Text(
                                entry.value == null
                                    ? '− ${entry.key} (deleted)'
                                    : (draft.baseline.containsKey(entry.key)
                                          ? '~ ${entry.key}'
                                          : '+ ${entry.key} (new)'),
                              ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      if (!result.isValid)
                        Text(
                          '${result.issues.length} validation issue(s) — fix before committing.',
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          labelText: 'Commit message',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _busy || draft.pendingChanges.isEmpty || !result.isValid
                            ? null
                            : _commit,
                        child: const Text('Commit to main'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('2. Dry run, then publish', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: _busy ? null : () => _triggerPublish(dryRun: true),
                            child: const Text('Dry run'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: _busy || _lastRun == null || !_lastRun!.succeeded
                                ? null
                                : () => _triggerPublish(dryRun: false),
                            child: const Text('Publish for real'),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: _refreshStatus,
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Refresh run status',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_lastRun != null)
                        Row(
                          children: [
                            Icon(
                              _lastRun!.isRunning
                                  ? Icons.hourglass_top
                                  : (_lastRun!.succeeded ? Icons.check_circle : Icons.error),
                              color: _lastRun!.isRunning
                                  ? null
                                  : (_lastRun!.succeeded ? Colors.green : Theme.of(context).colorScheme.error),
                            ),
                            const SizedBox(width: 8),
                            Text('${_lastRun!.status} · ${_lastRun!.conclusion ?? "running"}'),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => launchUrlString(_lastRun!.htmlUrl),
                              child: const Text('View run'),
                            ),
                          ],
                        )
                      else
                        const Text('No publish run yet.'),
                    ],
                  ),
                ),
              ),
              if (_status != null)
                Padding(padding: const EdgeInsets.only(top: 16), child: Text(_status!)),
            ],
          );
        },
      ),
    );
  }
}
