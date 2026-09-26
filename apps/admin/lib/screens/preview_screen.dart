import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/content_draft.dart';

/// A phone-frame preview of the staged draft. **Scoped down from the
/// original plan**: this renders a plain summary of the draft JSON
/// (title/kicker/subtitle/overview/events), not the real app screens —
/// wiring in `core_content`/`experience` for a pixel-exact preview (their
/// CDN-media loading, routing, and theming) was too large an integration
/// for this pass. Good enough to sanity-check bilingual text and event
/// ordering before publishing; not a substitute for checking the real app.
class PreviewScreen extends ConsumerStatefulWidget {
  const PreviewScreen({super.key});

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
  String? _slug;

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(contentDraftProvider).valueOrNull;
    if (draft == null) return const Center(child: CircularProgressIndicator());

    final slugs = draft.eraFiles.keys.map((f) => f.replaceAll('.json', '')).toList()..sort();
    _slug ??= slugs.isNotEmpty ? slugs.first : null;

    Map<String, dynamic>? era;
    if (_slug != null) {
      try {
        era = jsonDecode(draft.eraFiles['$_slug.json']!) as Map<String, dynamic>;
      } catch (_) {
        era = null;
      }
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Preview', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: _slug,
                  isExpanded: true,
                  items: [for (final s in slugs) DropdownMenuItem(value: s, child: Text(s))],
                  onChanged: (v) => setState(() => _slug = v),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Center(
              child: _PhoneFrame(child: era == null ? const Text('Invalid draft JSON') : _EraPreview(era: era)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      height: 720,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.grey.shade800, width: 8),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1a0505),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(child: child),
      ),
    );
  }
}

class _EraPreview extends StatelessWidget {
  const _EraPreview({required this.era});
  final Map<String, dynamic> era;

  String _loc(Object? field) {
    if (field is Map<String, dynamic>) return (field['en'] as String?) ?? (field['vi'] as String?) ?? '';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final events = (era['events'] as List? ?? const []).cast<Map<String, dynamic>>();
    return DefaultTextStyle(
      style: const TextStyle(color: Colors.white70),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_loc(era['kicker']), style: const TextStyle(fontSize: 12, letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text(
            _loc(era['title']),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(_loc(era['subtitle']), style: const TextStyle(fontStyle: FontStyle.italic)),
          const SizedBox(height: 16),
          Text(_loc(era['overview'])),
          const SizedBox(height: 24),
          Text('Events (${events.length})', style: const TextStyle(color: Colors.white, fontSize: 16)),
          const Divider(color: Colors.white24),
          for (final e in events)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('• ${_loc(e['title'])}'),
            ),
        ],
      ),
    );
  }
}
