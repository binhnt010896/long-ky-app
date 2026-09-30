import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/content_draft.dart';
import '../util/media_urls.dart';
import 'citation_field.dart';
import 'event_year_field.dart';
import 'localized_text_field.dart';
import 'media_slot.dart';

/// Add or edit one event — in an era, or standalone (Cycle N). [eraSlug] is
/// the era the event is (or will be) listed in, or null for a standalone event.
/// [eventId] is null when creating; the id is then generated from the title
/// and shown read-only once saved (an event id is public — app links, quiz
/// questions, analytics — so it's locked immediately, not just after a real
/// publish, to avoid a stale link the moment this dialog closes).
///
/// In an era, picking a figure who isn't on the roster adds them. A standalone
/// event has no roster, so it can only feature people who are on some era's
/// roster (every figure chip must open a page), and it must carry a dated year
/// and a hero image — the validator requires both.
class EventDialog extends ConsumerStatefulWidget {
  const EventDialog({
    required this.eraSlug,
    this.eventId,
    this.initial,
    super.key,
  });

  /// The era this event is (or will be) listed in; null for a standalone event.
  final String? eraSlug;

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
  String _relatedQuery = '';

  /// Whether to create a hero image slot (an assetRef pointing at a path the
  /// admin then uploads to). Only offered while the event has none.
  bool _addHero = false;
  final heroPathController = TextEditingController();

  bool get _isNew => widget.eventId == null;

  void _suggestId() {
    if (_idEdited || !_isNew) return;
    idController.text =
        ref.read(contentDraftProvider.notifier).suggestEventId(titleVi.text);
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(contentDraftProvider).valueOrNull;
    final standalone = widget.eraSlug == null;
    final eraEvents = widget.eraSlug == null
        ? const <String>[]
        : (draft?.eventIdsByEra[widget.eraSlug] ?? const <String>[]);
    final allEvents = [
      for (final e in draft?.events ?? const <Map<String, dynamic>>[])
        if (e['id'] != widget.eventId) e,
    ];
    // A standalone event may only feature people on some era's roster.
    final onRoster = draft?.peopleOnAnyRoster ?? const <String>{};
    final people = [
      for (final p in draft?.people ?? const <Map<String, dynamic>>[])
        if (!standalone || onRoster.contains(p['id']) || _figureIds.contains(p['id'])) p,
    ];
    final q = _relatedQuery.trim().toLowerCase();
    bool matches(Map<String, dynamic> e) {
      final t = e['title'] as Map?;
      return '${t?['vi'] ?? ''} ${t?['en'] ?? ''} ${e['id']}'.toLowerCase().contains(q);
    }
    // 237 events is too many chips: show what's selected, plus this era's
    // neighbours (or whatever the search finds).
    final relatedShown = [
      for (final e in allEvents)
        if (_relatedEventIds.contains(e['id']) ||
            (q.isEmpty ? eraEvents.contains(e['id']) : matches(e)))
          e,
    ].take(40).toList();

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
                // Expanded: the longest item ("Semi-historical — recorded but
                // disputed/embellished") overflowed the dialog's width.
                isExpanded: true,
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
                standalone
                    ? 'Only people on at least one era\'s roster — each chip has to open a page.'
                    : 'Picking someone not yet in this era\'s roster adds them automatically.',
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
              if (allEvents.isNotEmpty) ...[
                Text('Related events', style: Theme.of(context).textTheme.labelLarge),
                Text(
                  'Any event — in this era, another era, or standalone. '
                  '${q.isEmpty ? (standalone ? 'Search to find one.' : 'Showing this era\'s events; search for others.') : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                TextField(
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search, size: 18),
                    hintText: 'Search events…',
                  ),
                  onChanged: (v) => setState(() => _relatedQuery = v),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final e in relatedShown)
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
              if (!_isNew && draft != null && widget.initial?['hero'] != null)
                MediaSlot(
                  label: 'Hero image',
                  path: (widget.initial?['hero'] as Map?)?['flagship'] as String? ??
                      (widget.initial?['hero'] as Map?)?['reduced'] as String?,
                  manifest: MediaManifest.fromJson(
                    draft.files['content/media-manifest.json']!,
                  ),
                )
              else ...[
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _addHero,
                  title: Text(standalone
                      ? 'Hero image (required for a standalone event)'
                      : 'Hero image'),
                  subtitle: const Text(
                    'Creates the image slot. Save, then edit this event again to upload the picture.',
                  ),
                  onChanged: (v) => setState(() {
                    _addHero = v ?? false;
                    if (_addHero && heroPathController.text.isEmpty) {
                      heroPathController.text = _defaultHeroPath();
                    }
                  }),
                ),
                if (_addHero)
                  TextField(
                    controller: heroPathController,
                    decoration: const InputDecoration(
                      labelText: 'Source path in long-ky-sources',
                      helperText: 'Where the original goes once uploaded (a .png or .jpg).',
                    ),
                  ),
              ],
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
      // `hero` isn't edited by this form beyond creating the slot — an
      // existing one is carried over as-is so a save can never silently drop it.
      if (!_isNew && widget.initial?['hero'] != null)
        'hero': widget.initial!['hero']
      else if (_addHero && heroPathController.text.trim().isNotEmpty)
        'hero': _heroRef(id, heroPathController.text.trim()),
    };

    final controller = ref.read(contentDraftProvider.notifier);
    final era = widget.eraSlug;
    if (era != null) {
      for (final personId in _figureIds) {
        controller.ensureInRoster(era, personId);
      }
    }
    if (_isNew) {
      if (era != null) {
        controller.addEvent(era, id, event);
      } else {
        controller.addStandaloneEvent(id, event);
      }
    } else {
      controller.updateEvent(widget.eventId!, (_) => event..['id'] = id);
    }
    Navigator.pop(context);
  }

  String _defaultHeroPath() {
    final id = idController.text.trim().isEmpty ? 'su-kien-moi' : idController.text.trim();
    final era = widget.eraSlug;
    // The repo's convention for an in-era hero; standalone events get their own
    // folder since there is no era to put them under.
    return era == null ? 'events/$id/hero.png' : 'eras/$era/events/$id.png';
  }

  static Map<String, dynamic> _heroRef(String id, String path) => <String, dynamic>{
        'id': '$id-hero',
        'type': 'image',
        'role': 'hero',
        'flagship': path,
        'reduced': path,
        'caption': <String, dynamic>{
          'vi': 'Minh họa · phong cách sơn mài',
          'en': 'Illustration · lacquer style',
        },
      };

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
      heroPathController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }
}
