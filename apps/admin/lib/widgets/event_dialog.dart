import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/content_draft.dart';
import '../util/media_urls.dart';
import 'citation_field.dart';
import 'event_year_field.dart';
import 'localized_text_field.dart';
import 'media_slot.dart';

/// Add or edit one event on an era (Cycle K's events tab). [eventId] is
/// null when creating; the id is then generated from the title and shown
/// read-only once saved (an event id is public — app links, quiz questions,
/// analytics — so it's locked immediately, not just after a real publish,
/// to avoid a stale link the moment this dialog closes).
class EventDialog extends ConsumerStatefulWidget {
  const EventDialog({
    required this.eraSlug,
    this.eventId,
    this.initial,
    super.key,
  });

  final String eraSlug;

  /// Null when creating a new event.
  final String? eventId;

  /// The event's current JSON, required when [eventId] is set.
  final Map<String, dynamic>? initial;

  @override
  ConsumerState<EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends ConsumerState<EventDialog> {
  late final titleVi = TextEditingController(
    text: (widget.initial?['title'] as Map?)?['vi'] as String? ?? '',
  );
  late final titleEn = TextEditingController(
    text: (widget.initial?['title'] as Map?)?['en'] as String? ?? '',
  );
  late final summaryVi = TextEditingController(
    text: (widget.initial?['summary'] as Map?)?['vi'] as String? ?? '',
  );
  late final summaryEn = TextEditingController(
    text: (widget.initial?['summary'] as Map?)?['en'] as String? ?? '',
  );
  late final bodyVi = TextEditingController(
    text: (widget.initial?['body'] as Map?)?['vi'] as String? ?? '',
  );
  late final bodyEn = TextEditingController(
    text: (widget.initial?['body'] as Map?)?['en'] as String? ?? '',
  );
  late final detailsVi = TextEditingController(
    text: (widget.initial?['details'] as Map?)?['vi'] as String? ?? '',
  );
  late final detailsEn = TextEditingController(
    text: (widget.initial?['details'] as Map?)?['en'] as String? ?? '',
  );
  late final pullQuoteVi = TextEditingController(
    text: ((widget.initial?['pullQuote'] as Map?)?['text'] as Map?)?['vi'] as String? ?? '',
  );
  late final pullQuoteEn = TextEditingController(
    text: ((widget.initial?['pullQuote'] as Map?)?['text'] as Map?)?['en'] as String? ?? '',
  );
  late final attributionVi = TextEditingController(
    text: ((widget.initial?['pullQuote'] as Map?)?['attribution'] as Map?)?['vi'] as String? ?? '',
  );
  late final attributionEn = TextEditingController(
    text: ((widget.initial?['pullQuote'] as Map?)?['attribution'] as Map?)?['en'] as String? ?? '',
  );
  late final idController = TextEditingController(text: widget.eventId ?? '');

  late String _kind = widget.initial?['kind'] as String? ?? 'historical';
  late Map<String, dynamic> _year = (widget.initial?['year'] as Map?)?.cast<String, dynamic>() ??
      const {
        'display': {'vi': '', 'en': ''},
        'value': null,
        'approximate': false,
      };
  late Map<String, dynamic>? _citation =
      (widget.initial?['citation'] as Map?)?.cast<String, dynamic>();
  late bool _hasPullQuote = widget.initial?['pullQuote'] != null;
  late final Set<String> _figureIds =
      (widget.initial?['figureIds'] as List? ?? const []).cast<String>().toSet();
  late final Set<String> _relatedEventIds =
      (widget.initial?['relatedEventIds'] as List? ?? const []).cast<String>().toSet();
  bool _idEdited = false;

  bool get _isNew => widget.eventId == null;

  void _suggestId() {
    if (_idEdited || !_isNew) return;
    idController.text =
        ref.read(contentDraftProvider.notifier).suggestEventId(titleVi.text);
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(contentDraftProvider).valueOrNull;
    final eraText = draft?.files['content/eras/${widget.eraSlug}.json'];
    final era = eraText == null ? null : _tryDecode(eraText);
    final otherEvents = (era?['events'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .where((e) => e['id'] != widget.eventId)
        .toList();
    final people = draft?.people ?? const [];

    return AlertDialog(
      title: Text(_isNew ? 'New event' : 'Edit event'),
      content: SizedBox(
        width: 640,
        height: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: idController,
                enabled: _isNew,
                onChanged: (_) => _idEdited = true,
                decoration: InputDecoration(
                  labelText: 'id',
                  helperText: _isNew
                      ? 'Also becomes the event\'s slug — locked once created (used in app links, the quiz and analytics).'
                      : 'Locked — used in app links, the quiz and analytics.',
                ),
              ),
              const SizedBox(height: 12),
              LocalizedTextField(
                label: 'Title',
                vi: titleVi..addListener(_suggestId),
                en: titleEn,
              ),
              LocalizedTextField(label: 'Summary', vi: summaryVi, en: summaryEn),
              LocalizedTextField(label: 'Body', vi: bodyVi, en: bodyEn, maxLines: 4),
              LocalizedTextField(
                label: 'Details',
                vi: detailsVi,
                en: detailsEn,
                maxLines: 4,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'Kind'),
                items: const [
                  DropdownMenuItem(
                    value: 'historical',
                    child: Text('Historical — recorded as fact'),
                  ),
                  DropdownMenuItem(
                    value: 'semi-historical',
                    child: Text('Semi-historical — recorded but disputed/embellished'),
                  ),
                  DropdownMenuItem(value: 'legend', child: Text('Legend — folk account')),
                ],
                onChanged: (v) => setState(() => _kind = v ?? 'historical'),
              ),
              const SizedBox(height: 8),
              EventYearField(initial: _year, onChanged: (v) => _year = v),
              const SizedBox(height: 8),
              CitationField(
                label: 'Citation',
                initial: _citation,
                onChanged: (v) => _citation = v,
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _hasPullQuote,
                title: const Text('Pull quote'),
                onChanged: (v) => setState(() => _hasPullQuote = v ?? false),
              ),
              if (_hasPullQuote) ...[
                LocalizedTextField(label: 'Quote', vi: pullQuoteVi, en: pullQuoteEn),
                LocalizedTextField(label: 'Attribution', vi: attributionVi, en: attributionEn),
              ],
              const SizedBox(height: 8),
              Text('Figures', style: Theme.of(context).textTheme.labelLarge),
              Text(
                'Picking someone not yet in this era\'s roster adds them automatically.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final p in people)
                    FilterChip(
                      label: Text((p['name'] as Map?)?['vi'] as String? ?? p['id'] as String),
                      selected: _figureIds.contains(p['id']),
                      onSelected: (sel) => setState(() {
                        if (sel) {
                          _figureIds.add(p['id'] as String);
                        } else {
                          _figureIds.remove(p['id']);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (otherEvents.isNotEmpty) ...[
                Text('Related events', style: Theme.of(context).textTheme.labelLarge),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final e in otherEvents)
                      FilterChip(
                        label: Text((e['title'] as Map?)?['vi'] as String? ?? e['id'] as String),
                        selected: _relatedEventIds.contains(e['id']),
                        onSelected: (sel) => setState(() {
                          if (sel) {
                            _relatedEventIds.add(e['id'] as String);
                          } else {
                            _relatedEventIds.remove(e['id']);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (!_isNew && draft != null)
                MediaSlot(
                  label: 'Hero image',
                  path: (widget.initial?['hero'] as Map?)?['flagship'] as String? ??
                      (widget.initial?['hero'] as Map?)?['reduced'] as String?,
                  manifest: MediaManifest.fromJson(
                    draft.files['content/media-manifest.json']!,
                  ),
                )
              else
                Text(
                  'The hero image can be added from the Images tab once this event is created.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: Text(_isNew ? 'Create' : 'Save')),
      ],
    );
  }

  void _save() {
    final id = idController.text.trim();
    final work = _citation?['work'] as String?;
    if (id.isEmpty || titleVi.text.trim().isEmpty || work == null || work.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Id, title (vi) and a citation work are required.')),
      );
      return;
    }

    final event = <String, dynamic>{
      'kind': _kind,
      'year': _year,
      'title': localizedValue(titleVi, titleEn),
      'summary': localizedValue(summaryVi, summaryEn),
      if (bodyVi.text.isNotEmpty || bodyEn.text.isNotEmpty)
        'body': localizedValue(bodyVi, bodyEn),
      if (detailsVi.text.isNotEmpty || detailsEn.text.isNotEmpty)
        'details': localizedValue(detailsVi, detailsEn),
      'citation': _citation,
      if (_hasPullQuote)
        'pullQuote': {
          'text': localizedValue(pullQuoteVi, pullQuoteEn),
          if (attributionVi.text.isNotEmpty || attributionEn.text.isNotEmpty)
            'attribution': localizedValue(attributionVi, attributionEn),
        },
      if (_figureIds.isNotEmpty) 'figureIds': _figureIds.toList(),
      if (_relatedEventIds.isNotEmpty) 'relatedEventIds': _relatedEventIds.toList(),
      // `slug`/`order`/`hero` aren't edited by this form — carried over
      // as-is from the event being edited so a save can never silently
      // drop them (order especially: losing it would break the K7
      // contiguous-order rule for the whole era).
      if (!_isNew) ...{
        'slug': id,
        'order': widget.initial!['order'],
        if (widget.initial?['hero'] != null) 'hero': widget.initial!['hero'],
      },
    };

    final controller = ref.read(contentDraftProvider.notifier);
    for (final personId in _figureIds) {
      controller.ensureInRoster(widget.eraSlug, personId);
    }
    if (_isNew) {
      controller.addEvent(widget.eraSlug, id, event);
    } else {
      controller.updateEvent(widget.eraSlug, widget.eventId!, (_) => event..['id'] = id);
    }
    Navigator.pop(context);
  }

  Map<String, dynamic>? _tryDecode(String text) {
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    for (final c in [
      titleVi,
      titleEn,
      summaryVi,
      summaryEn,
      bodyVi,
      bodyEn,
      detailsVi,
      detailsEn,
      pullQuoteVi,
      pullQuoteEn,
      attributionVi,
      attributionEn,
      idController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }
}
