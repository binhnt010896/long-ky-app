import 'dart:convert';

import '../state/content_draft.dart';

/// One place an asset path is referenced from — a period cover, an era's
/// cover/scene layer/event hero, or a person's portrait/avatar/fullBody.
/// Several usages can share the same source [path] (e.g. two eras'
/// characters both pointing at the same person's portrait).
class MediaUsage {
  const MediaUsage(this.group, this.label);
  final String group;
  final String label;

  @override
  String toString() => '$group · $label';
}

/// path → every place in the draft that references it, built by walking
/// every period/era/person's asset refs. This is the Media Library's whole
/// index — an item with no manifest entry here is exactly the "referenced
/// but never published" failure mode that bit Hai Bà Trưng's scene art in
/// Cycle G.
Map<String, List<MediaUsage>> collectMediaRefs(ContentDraft draft) {
  final refs = <String, List<MediaUsage>>{};
  void add(String? path, String group, String label) {
    if (path == null || path.isEmpty) return;
    (refs[path] ??= []).add(MediaUsage(group, label));
  }

  String? sourceOf(Object? assetRef) {
    if (assetRef is! Map) return null;
    return (assetRef['flagship'] as String?) ?? (assetRef['reduced'] as String?);
  }

  for (final period in draft.periods) {
    final title = (period['title'] as Map?)?['en'] as String? ?? period['id'] as String;
    add(sourceOf(period['cover']), 'Period', title);
  }

  for (final entry in draft.eraFiles.entries) {
    Map<String, dynamic> era;
    try {
      era = jsonDecode(entry.value) as Map<String, dynamic>;
    } catch (_) {
      continue;
    }
    final slug = entry.key.replaceAll('.json', '');
    final eraTitle = (era['title'] as Map?)?['en'] as String? ?? slug;
    final group = 'Era: $eraTitle';
    add(sourceOf(era['cover']), group, 'Cover');
    final scene = era['scene'];
    if (scene is Map) {
      final layers = scene['layers'];
      if (layers is List) {
        for (var i = 0; i < layers.length; i++) {
          add(sourceOf(layers[i]), group, 'Scene layer ${i + 1}');
        }
      }
    }
    final events = era['events'];
    if (events is List) {
      for (final e in events) {
        if (e is! Map) continue;
        final title = (e['title'] as Map?)?['en'] as String? ?? e['id'] as String? ?? '';
        add(sourceOf(e['hero']), group, 'Event hero: $title');
      }
    }
  }

  for (final person in draft.people) {
    final name = (person['name'] as Map?)?['en'] as String? ?? person['id'] as String;
    final group = 'Person: $name';
    add(sourceOf(person['portrait']), group, 'Portrait');
    add(sourceOf(person['avatar']), group, 'Avatar');
    add(sourceOf(person['fullBody']), group, 'Full body');
  }

  return refs;
}
