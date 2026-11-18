import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../state/providers.dart';
import '../../state/visit_store.dart';
import '../../theme/content_assets.dart';
import '../../widgets/circle_icon_button.dart';
import '../../widgets/lang_toggle.dart';
import '../../widgets/pressable.dart';
import '../era/widgets/timeline_event_card.dart' show ReadMark;
import 'standalone_placement.dart';
import '../../widgets/load_error_view.dart';

/// Global Timeline — every era's events threaded onto one continuous chronology,
/// so the whole sweep of Việt history reads as a single line. Era chapters break
/// the spine; each event and era is a tap into its detail. A keyword field
/// filters the spine to the matching events (diacritic-insensitive, so "bach
/// dang" finds "Bạch Đằng") and lists the people it matches above them; a row
/// of dynasty chips narrows the unfiltered spine to one period. Events the
/// reader has opened carry a "read" tick. VI primary, EN toggle.
class GlobalTimelineScreen extends ConsumerStatefulWidget {
  const GlobalTimelineScreen({this.focusSearch = false, super.key});

  /// Opens with the keyboard up in the search field (`/timeline?search=1`,
  /// the Sảnh's "Tìm kiếm" row).
  final bool focusSearch;

  @override
  ConsumerState<GlobalTimelineScreen> createState() =>
      _GlobalTimelineScreenState();
}

class _GlobalTimelineScreenState extends ConsumerState<GlobalTimelineScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  /// The dynasty the spine is narrowed to (a period id), or null for all.
  String? _period;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final erasAsync = ref.watch(erasProvider);
    final periods = ref.watch(periodsProvider).valueOrNull;
    final lang = ref.watch(langProvider);
    // Events no era lists (none until one is authored): their own nodes.
    final standalone =
        ref.watch(standaloneEventsProvider).valueOrNull ?? const <HistoryEvent>[];
    final people = ref.watch(peopleProvider).valueOrNull;
    final visited =
        ref.watch(visitedProvider).valueOrNull ?? const <String>{};
    bool isRead(HistoryEvent e) => visited.contains(VisitKey.event(e.id));

    return Scaffold(
      backgroundColor: VSColors.lacquer,
      body: SafeArea(
        bottom: false,
        child: erasAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: VSColors.gold),
          ),
          error: (e, _) => LoadErrorView(
          error: e,
          onRetry: () => ref.invalidate(erasProvider),
        ),
          data: (eras) {
            final totalEvents = eras.fold<int>(
                  0,
                  (sum, e) => sum + e.events.length,
                ) +
                standalone.length;
            final placed = StandalonePlacement.place(eras, standalone);

            // Filter: match each event's own text and its era/dynasty context,
            // both folded to remove diacritics so an unaccented query still
            // hits. An era-level match surfaces all of that era's events.
            final query = _foldSearch(_query.trim());
            final filtering = query.isNotEmpty;
            final matches = <_EraMatch>[];
            final standaloneMatches = <HistoryEvent>[];
            final peopleMatches = <Character>[];
            var resultCount = 0;
            if (filtering) {
              // People first: a name should reach the person's own page, not
              // only the events they appear in.
              for (final c in people?.byId.values ?? const <Character>[]) {
                if (_personHaystack(c).contains(query)) peopleMatches.add(c);
              }
              resultCount += peopleMatches.length;
              for (final event in standalone) {
                if (_eventHaystack(null, event, people).contains(query)) {
                  standaloneMatches.add(event);
                }
              }
              resultCount += standaloneMatches.length;
              for (final era in eras) {
                final eraHay = _eraHaystack(era, periods);
                final hit = <HistoryEvent>[];
                for (final event in era.events) {
                  if (eraHay.contains(query) ||
                      _eventHaystack(era, event, people).contains(query)) {
                    hit.add(event);
                  }
                }
                if (hit.isNotEmpty) {
                  matches.add(_EraMatch(era, hit));
                  resultCount += hit.length;
                }
              }
            }

            // The dynasties that actually hold eras, in order — the chip row.
            final periodChips = <Period>[
              for (final p in periods?.ordered ?? const <Period>[])
                if (eras.any((e) => e.period == p.id)) p,
            ];
            final shown = <int>[
              for (var ei = 0; ei < eras.length; ei++)
                if (_period == null || eras[ei].period == _period) ei,
            ];

            return CustomScrollView(
              slivers: <Widget>[
                // Floats back into view as soon as you scroll up (not only at
                // the very top) and snaps fully open/shut rather than
                // tracking the scroll offset partway.
                SliverAppBar(
                  backgroundColor: VSColors.lacquer,
                  elevation: 0,
                  floating: true,
                  snap: true,
                  toolbarHeight: 58,
                  automaticallyImplyLeading: false,
                  titleSpacing: 0,
                  title: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: VSSpacing.xl,
                    ),
                    child: Row(
                      children: <Widget>[
                        Builder(
                          builder: (context) => CircleIconButton.back(
                            onTap: () => context.canPop()
                                ? context.pop()
                                : context.go('/'),
                          ),
                        ),
                        const Spacer(),
                        Builder(
                          builder: (context) => CircleIconButton(
                            icon: Icons.map_outlined,
                            labelVi: 'Bản đồ lãnh thổ',
                            labelEn: 'Territory atlas',
                            onTap: () => context.push('/map'),
                          ),
                        ),
                        const SizedBox(width: VSSpacing.xxs),
                        const LangToggle(compact: true),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: VSSpacing.xxl),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(<Widget>[
                      _HeaderBody(
                        eraCount: eras.length,
                        eventCount: totalEvents,
                        lang: lang,
                        controller: _controller,
                        autofocus: widget.focusSearch,
                        filtering: filtering,
                        resultCount: resultCount,
                        periods: periodChips,
                        period: _period,
                        onPeriod: (id) => setState(() => _period = id),
                        onChanged: (v) => setState(() => _query = v),
                        onClear: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      ),
                      if (!filtering && _period == null)
                        for (final event in placed.beforeFirst)
                          _standaloneEntry(context, event, lang, isRead(event)),
                      if (!filtering)
                        for (final ei in shown) ...<Widget>[
                          if (ei == 0 || eras[ei].period != eras[ei - 1].period)
                            _PeriodHeader(
                              period: eras[ei].period == null
                                  ? null
                                  : periods?[eras[ei].period!],
                              lang: lang,
                            ),
                          _EraChapter(
                            era: eras[ei],
                            lang: lang,
                            isFirst: ei == shown.first,
                            onTap: () => context.push('/era/${eras[ei].slug}'),
                          ),
                          for (final event in eras[ei].events)
                            _EventEntry(
                              event: event,
                              lang: lang,
                              read: isRead(event),
                              onTap: () => context.push(
                                '/era/${eras[ei].slug}/event/${event.id}',
                              ),
                            ),
                          for (final event in placed.afterEra[ei] ?? const <HistoryEvent>[])
                            _standaloneEntry(context, event, lang, isRead(event)),
                        ]
                      else if (matches.isEmpty &&
                          standaloneMatches.isEmpty &&
                          peopleMatches.isEmpty)
                        _EmptyResults(lang: lang, query: _query.trim())
                      else ...<Widget>[
                        if (peopleMatches.isNotEmpty) ...<Widget>[
                          _ResultsLabel(
                            label: lang == Lang.vi ? 'NHÂN VẬT' : 'PEOPLE',
                          ),
                          for (final c in peopleMatches)
                            _PersonEntry(
                              person: c,
                              lang: lang,
                              // The router sends a rostered person on to their
                              // home era's page; a standalone one opens here.
                              onTap: () => context.push('/nhan-vat/${c.id}'),
                            ),
                          if (matches.isNotEmpty || standaloneMatches.isNotEmpty)
                            _ResultsLabel(
                              label: lang == Lang.vi ? 'SỰ KIỆN' : 'EVENTS',
                            ),
                        ],
                        for (var mi = 0; mi < matches.length; mi++) ...<Widget>[
                          if (mi == 0 ||
                              matches[mi].era.period !=
                                  matches[mi - 1].era.period)
                            _PeriodHeader(
                              period: matches[mi].era.period == null
                                  ? null
                                  : periods?[matches[mi].era.period!],
                              lang: lang,
                            ),
                          _EraChapter(
                            era: matches[mi].era,
                            lang: lang,
                            isFirst: mi == 0,
                            onTap: () =>
                                context.push('/era/${matches[mi].era.slug}'),
                          ),
                          for (final event in matches[mi].events)
                            _EventEntry(
                              event: event,
                              lang: lang,
                              read: isRead(event),
                              onTap: () => context.push(
                                '/era/${matches[mi].era.slug}/event/${event.id}',
                              ),
                            ),
                        ],
                      ],
                      if (filtering)
                        for (final event in standaloneMatches)
                          _standaloneEntry(context, event, lang, isRead(event)),
                      if (!filtering || matches.isNotEmpty || standaloneMatches.isNotEmpty)
                        const _EndCap(),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One standalone event's node — opens `/su-kien/:id`.
Widget _standaloneEntry(
        BuildContext context, HistoryEvent event, Lang lang, bool read) =>
    _EventEntry(
      event: event,
      lang: lang,
      standalone: true,
      read: read,
      onTap: () => context.push('/su-kien/${event.id}'),
    );

/// An era paired with the subset of its events that matched the active query.
class _EraMatch {
  const _EraMatch(this.era, this.events);
  final Era era;
  final List<HistoryEvent> events;
}

/// Folds a string for search: lowercased with Vietnamese diacritics removed
/// (and đ → d), so the query matches regardless of accents. Content itself is
/// never altered — this only builds the comparison keys.
String _foldSearch(String s) {
  final lower = s.toLowerCase();
  final sb = StringBuffer();
  for (final r in lower.runes) {
    sb.writeCharCode(_diacriticFold[r] ?? r);
  }
  return sb.toString();
}

/// Searchable key for an era's own identity plus its dynasty context, so a
/// query like "nhà Trần" or "Lam Sơn" surfaces every event under it.
String _eraHaystack(Era era, PeriodRegistry? periods) {
  final p = era.period == null ? null : periods?[era.period!];
  return _foldSearch(
    <String>[
      era.title.vi,
      era.title.en ?? '',
      era.kicker.vi,
      era.kicker.en ?? '',
      if (p != null) ...<String>[
        p.title.vi,
        p.title.en ?? '',
        p.kicker.vi,
        p.kicker.en ?? '',
      ],
    ].join(' '),
  );
}

/// Searchable key for one person: name and epithet, both languages.
String _personHaystack(Character c) => _foldSearch(<String>[
      c.name.vi,
      c.name.en ?? '',
      c.epithet?.vi ?? '',
      c.epithet?.en ?? '',
    ].join(' '));

/// Searchable key for one event: its title, summary, displayed year and the
/// names/epithets of the figures who appear in it (both languages).
String _eventHaystack(Era? era, HistoryEvent event, PeopleRegistry? people) {
  final parts = <String>[
    event.title.vi,
    event.title.en ?? '',
    event.summary.vi,
    event.summary.en ?? '',
    event.year.display.vi,
    event.year.display.en ?? '',
  ];
  // A standalone event has no era roster: its figures come from the registry.
  final figures = era != null
      ? era.charactersFor(event)
      : <Character>[
          for (final id in event.figureIds)
            if (people?[id] case final c?) c,
        ];
  for (final c in figures) {
    parts
      ..add(c.name.vi)
      ..add(c.name.en ?? '')
      ..add(c.epithet?.vi ?? '')
      ..add(c.epithet?.en ?? '');
  }
  return _foldSearch(parts.join(' '));
}

/// Base-letter lookup for [_foldSearch]. Maps each accented Vietnamese code
/// unit to its unaccented base; anything absent is left unchanged.
final Map<int, int> _diacriticFold = _buildDiacriticFold();

Map<int, int> _buildDiacriticFold() {
  final map = <int, int>{};
  void add(String variants, String base) {
    final b = base.runes.first;
    for (final r in variants.runes) {
      map[r] = b;
    }
  }

  add('àáạảãâầấậẩẫăằắặẳẵ', 'a');
  add('èéẹẻẽêềếệểễ', 'e');
  add('ìíịỉĩ', 'i');
  add('òóọỏõôồốộổỗơờớợởỡ', 'o');
  add('ùúụủũưừứựửữ', 'u');
  add('ỳýỵỷỹ', 'y');
  add('đ', 'd');
  return map;
}

/// Everything below the pinned top bar: overline, title, result count and the
/// search field. Scrolls away normally (the top bar — back/map/lang — is a
/// SliverAppBar above this in the CustomScrollView).
class _HeaderBody extends StatelessWidget {
  const _HeaderBody({
    required this.eraCount,
    required this.eventCount,
    required this.lang,
    required this.controller,
    required this.autofocus,
    required this.filtering,
    required this.resultCount,
    required this.periods,
    required this.period,
    required this.onPeriod,
    required this.onChanged,
    required this.onClear,
  });

  final int eraCount;
  final int eventCount;
  final Lang lang;
  final TextEditingController controller;
  final bool autofocus;
  final bool filtering;
  final int resultCount;

  /// The dynasty chips, and which one (a period id) the spine is narrowed to.
  final List<Period> periods;
  final String? period;
  final ValueChanged<String?> onPeriod;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final overline = lang == Lang.vi ? 'NIÊN BIỂU' : 'TIMELINE';
    final title = lang == Lang.vi ? 'Dòng thời gian' : 'The timeline';
    final sub = filtering
        ? (lang == Lang.vi
              ? (resultCount == 1 ? '1 kết quả' : '$resultCount kết quả')
              : (resultCount == 1 ? '1 result' : '$resultCount results'))
        : (lang == Lang.vi
              ? '$eraCount kỷ nguyên · $eventCount sự kiện'
              : '$eraCount eras · $eventCount events');
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        VSSpacing.xl,
        VSSpacing.md,
        VSSpacing.xl,
        VSSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            overline,
            style: VSType.overline.copyWith(
              color: VSColors.goldBright,
              letterSpacing: VSType.track(0.3, 10),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: VSSpacing.sm),
          Text(title, style: VSType.title),
          const SizedBox(height: 6),
          Text(
            sub,
            style: VSType.caption.copyWith(
              color: VSColors.inkMuted,
              letterSpacing: VSType.track(0.16, 12),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: VSSpacing.md),
          _SearchField(
            controller: controller,
            lang: lang,
            autofocus: autofocus,
            filtering: filtering,
            onChanged: onChanged,
            onClear: onClear,
          ),
          // Jump to a dynasty: 237 events is a long way to scroll. Hidden
          // while searching (a query already narrows the spine).
          if (!filtering && periods.length > 1) ...<Widget>[
            const SizedBox(height: VSSpacing.xs),
            SizedBox(
              height: kMinTapTarget,
              child: ListView(
                key: const ValueKey<String>('timeline-period-chips'),
                scrollDirection: Axis.horizontal,
                // Bleed to the screen edges so chips scroll under them.
                clipBehavior: Clip.none,
                children: <Widget>[
                  _PeriodChip(
                    label: lang == Lang.vi ? 'Tất cả' : 'All',
                    selected: period == null,
                    onTap: () => onPeriod(null),
                  ),
                  for (final p in periods)
                    _PeriodChip(
                      label: p.title.resolve(lang),
                      selected: period == p.id,
                      onTap: () => onPeriod(period == p.id ? null : p.id),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One dynasty in the jump row — a pill that lights when the spine is narrowed
/// to it.
class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: VSSpacing.xs),
      child: Pressable(
        onTap: onTap,
        haptic: true,
        selected: selected,
        minSize: kMinTapTarget,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? VSColors.goldWash : null,
            borderRadius: VSRadii.pillAll,
            border: Border.all(
              color: selected ? VSColors.goldBright : VSColors.goldBorder,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            style: VSType.caption.copyWith(
              color: selected ? VSColors.goldBright : VSColors.inkSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// A section label over a group of search results ("NHÂN VẬT", "SỰ KIỆN").
class _ResultsLabel extends StatelessWidget {
  const _ResultsLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          VSSpacing.xl, VSSpacing.lg, VSSpacing.xl, VSSpacing.xs),
      child: Text(label,
          style: VSType.overline.copyWith(color: VSColors.goldBright)),
    );
  }
}

/// One person in the search results — opens their page.
class _PersonEntry extends StatelessWidget {
  const _PersonEntry({
    required this.person,
    required this.lang,
    required this.onTap,
  });

  final Character person;
  final Lang lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final epithet = person.epithet?.resolve(lang);
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            VSSpacing.xl, VSSpacing.sm, VSSpacing.xl, VSSpacing.sm),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: VSColors.goldBorder),
              ),
              child: const Icon(Icons.person_outline,
                  size: 18, color: VSColors.gold),
            ),
            const SizedBox(width: VSSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    person.name.resolve(lang),
                    style: VSType.cardTitle.copyWith(fontSize: 15),
                  ),
                  if (epithet != null && epithet.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        epithet,
                        style: VSType.caption.copyWith(color: VSColors.gold),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: VSSpacing.sm),
            const Icon(Icons.arrow_forward, size: 15, color: VSColors.inkMuted),
          ],
        ),
      ),
    );
  }
}

/// The keyword field that drives the timeline filter. A leading search glyph, a
/// single-line input, and a clear affordance that appears once there is a query.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.lang,
    required this.autofocus,
    required this.filtering,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final Lang lang;
  final bool autofocus;
  final bool filtering;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hint = lang == Lang.vi
        ? 'Tìm sự kiện, nhân vật, triều đại…'
        : 'Search events, figures, dynasties…';
    return Container(
      decoration: BoxDecoration(
        color: VSColors.lacquerRaised,
        borderRadius: VSRadii.cardAll,
        border: Border.all(color: VSColors.goldBorder),
      ),
      padding: const EdgeInsets.only(left: VSSpacing.md),
      child: Row(
        children: <Widget>[
          const Icon(Icons.search, size: 18, color: VSColors.gold),
          const SizedBox(width: VSSpacing.sm),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              cursorColor: VSColors.gold,
              style: VSType.body.copyWith(fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: VSType.body.copyWith(
                  color: VSColors.inkMuted,
                  fontSize: 14,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: VSSpacing.md,
                ),
              ),
            ),
          ),
          if (filtering)
            Pressable(
              key: const ValueKey<String>('timeline-search-clear'),
              onTap: onClear,
              minSize: kMinTapTarget,
              semanticLabel: lang == Lang.vi ? 'Xoá từ khoá' : 'Clear search',
              child: const Icon(Icons.close, size: 18, color: VSColors.inkMuted),
            )
          else
            const SizedBox(width: VSSpacing.md),
        ],
      ),
    );
  }
}

/// Shown when a query matches nothing — keeps the spine from collapsing into a
/// bare header and tells the reader why the timeline is empty.
class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.lang, required this.query});

  final Lang lang;
  final String query;

  @override
  Widget build(BuildContext context) {
    final msg = lang == Lang.vi
        ? 'Không tìm thấy sự kiện hay nhân vật nào cho “$query”.'
        : 'No events or people found for “$query”.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        VSSpacing.xl,
        VSSpacing.xxl,
        VSSpacing.xl,
        VSSpacing.xxl,
      ),
      child: Column(
        children: <Widget>[
          const Icon(Icons.search_off, size: 40, color: VSColors.inkMuted),
          const SizedBox(height: VSSpacing.md),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: VSType.body.copyWith(color: VSColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// A dynasty band that breaks the spine into periods: the dynasty's cover as a
/// dim backdrop, with its kicker, name and span. Renders a slim divider when the
/// period registry hasn't resolved (or the era has no period).
class _PeriodHeader extends StatelessWidget {
  const _PeriodHeader({required this.period, required this.lang});

  final Period? period;
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    final p = period;
    if (p == null) {
      return const Padding(
        padding: EdgeInsets.only(left: 44, top: VSSpacing.lg),
        child: Divider(color: VSColors.goldBorder, height: 1),
      );
    }
    final accent = VSColors.fromHex(p.accent);
    final coverPath = p.cover?.reduced ?? p.cover?.flagship;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        VSSpacing.md,
        VSSpacing.xl,
        VSSpacing.xl,
        VSSpacing.xs,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: <Widget>[
            if (coverPath != null)
              Positioned.fill(
                child: Image(
                  image: contentImageProvider(
                    coverPath,
                    decodeWidth: decodeWidthFor(
                      context,
                      MediaQuery.sizeOf(context).width,
                    ),
                  ),
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  frameBuilder: fadeInImageFrame,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            // Flat dim mask under the left-to-right scrim below, so the art
            // reads a touch darker everywhere (not just under the text) and
            // the kicker/title/span stay legible against bright covers.
            const Positioned.fill(
              child: ColoredBox(color: Color.fromRGBO(0, 0, 0, 0.1)),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: <Color>[
                      VSColors.lacquer,
                      VSColors.lacquer.withValues(alpha: 0.72),
                      VSColors.lacquer.withValues(alpha: 0.30),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              constraints: const BoxConstraints(minHeight: 74),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: accent, width: 3)),
              ),
              padding: const EdgeInsets.fromLTRB(
                VSSpacing.lg,
                VSSpacing.md,
                VSSpacing.lg,
                VSSpacing.md,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    p.kicker.resolve(lang).toUpperCase(),
                    style: VSType.overline.copyWith(
                      color: accent,
                      letterSpacing: VSType.track(0.3, 10),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p.title.resolve(lang),
                    style: VSType.title.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    p.yearRange.display.resolve(lang),
                    style: VSType.label.copyWith(
                      color: VSColors.gold,
                      fontSize: 11.5,
                      letterSpacing: VSType.track(0.14, 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The leading rail: a continuous vertical line with a node at [nodeTop].
class _Spine extends StatelessWidget {
  const _Spine({
    required this.nodeColor,
    required this.nodeSize,
    required this.nodeTop,
    this.glow = false,
    this.ring = false,
    this.lineFromTop = true,
    this.lineToBottom = true,
  });

  final Color nodeColor;
  final double nodeSize;
  final double nodeTop;
  final bool glow;

  /// Draws a concentric gold halo ring around the node — reserved for a
  /// flagship "peak" era, so its node reads as the dominant one on the spine.
  final bool ring;
  final bool lineFromTop;
  final bool lineToBottom;

  static const double _cx = 22;

  @override
  Widget build(BuildContext context) {
    final nodeCenter = nodeTop + nodeSize / 2;
    final ringSize = nodeSize + 10;
    return SizedBox(
      width: 44,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: _cx - 1,
            top: lineFromTop ? 0 : nodeCenter,
            bottom: lineToBottom ? 0 : null,
            height: lineToBottom ? null : 0,
            child: Container(width: 2, color: VSColors.goldBorder),
          ),
          if (ring)
            Positioned(
              left: _cx - ringSize / 2,
              top: nodeCenter - ringSize / 2,
              child: Container(
                width: ringSize,
                height: ringSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: VSColors.goldGlow, width: 1.5),
                ),
              ),
            ),
          Positioned(
            left: _cx - nodeSize / 2,
            top: nodeTop,
            child: Container(
              width: nodeSize,
              height: nodeSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: nodeColor,
                border: Border.all(color: VSColors.lacquer, width: 2),
                boxShadow: glow
                    ? <BoxShadow>[
                        BoxShadow(
                          color: nodeColor.withValues(alpha: 0.6),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EraChapter extends StatelessWidget {
  const _EraChapter({
    required this.era,
    required this.lang,
    required this.isFirst,
    required this.onTap,
  });

  final Era era;
  final Lang lang;
  final bool isFirst;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = VSColors.fromHex(era.palette.accent);
    final peak = era.flagship;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Spine(
            nodeColor: accent,
            nodeSize: peak ? 22 : 16,
            nodeTop: peak ? 23 : 26,
            glow: true,
            ring: peak,
            lineFromTop: !isFirst,
          ),
          Expanded(
            child: Pressable(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  VSSpacing.sm,
                  VSSpacing.lg,
                  VSSpacing.xl,
                  VSSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (peak) ...<Widget>[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.star_rounded,
                            size: 12,
                            color: VSColors.goldBright,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            lang == Lang.en ? 'PEAK' : 'ĐỈNH CAO',
                            style: VSType.overline.copyWith(
                              color: VSColors.goldBright,
                              letterSpacing: VSType.track(0.3, 10),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                    ],
                    Text(
                      era.kicker.resolve(lang).toUpperCase(),
                      style: VSType.overline.copyWith(
                        color: accent,
                        letterSpacing: VSType.track(0.28, 10),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            era.title.resolve(lang),
                            style: VSType.title.copyWith(fontSize: 22),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: VSColors.goldBright,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      era.yearRange.display.resolve(lang),
                      style: VSType.label.copyWith(
                        color: VSColors.gold,
                        fontSize: 12,
                        letterSpacing: VSType.track(0.14, 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventEntry extends StatelessWidget {
  const _EventEntry({
    required this.event,
    required this.lang,
    required this.onTap,
    this.standalone = false,
    this.read = false,
  });

  final HistoryEvent event;
  final Lang lang;
  final VoidCallback onTap;

  /// The reader has opened this event: brighter node, and a tick by the arrow.
  final bool read;

  /// A standalone event (no era), marked "Sự kiện riêng" under its year.
  final bool standalone;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Spine(
            nodeColor: read ? VSColors.goldBright : VSColors.gold,
            nodeSize: 9,
            nodeTop: 16,
          ),
          Expanded(
            child: Pressable(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  VSSpacing.sm,
                  VSSpacing.sm,
                  VSSpacing.xl,
                  VSSpacing.sm,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            event.year.display.resolve(lang),
                            style: VSType.caption.copyWith(
                              color: VSColors.gold,
                              fontWeight: FontWeight.w500,
                              letterSpacing: VSType.track(0.14, 11),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            event.title.resolve(lang),
                            style: VSType.cardTitle.copyWith(fontSize: 15),
                          ),
                          if (standalone)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                lang == Lang.vi ? 'Sự kiện riêng' : 'Standalone event',
                                style: VSType.caption.copyWith(
                                  color: VSColors.inkMuted,
                                  letterSpacing: VSType.track(0.14, 10),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: VSSpacing.sm),
                    if (read) ...<Widget>[
                      ReadMark(lang: lang, showLabel: false),
                      const SizedBox(width: VSSpacing.xs),
                    ],
                    const Icon(
                      Icons.arrow_forward,
                      size: 15,
                      color: VSColors.inkMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small terminal node that closes the spine.
class _EndCap extends StatelessWidget {
  const _EndCap();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 40,
      child: _Spine(
        nodeColor: VSColors.goldBorder,
        nodeSize: 7,
        nodeTop: 0,
        lineToBottom: false,
      ),
    );
  }
}
