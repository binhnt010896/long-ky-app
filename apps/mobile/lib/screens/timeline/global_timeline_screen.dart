import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../state/providers.dart';
import '../../theme/content_assets.dart';
import '../../widgets/circle_icon_button.dart';
import '../../widgets/lang_toggle.dart';

/// Global Timeline — every era's events threaded onto one continuous chronology,
/// so the whole sweep of Việt history reads as a single line. Era chapters break
/// the spine; each event and era is a tap into its detail. A keyword field
/// filters the spine to the matching events (diacritic-insensitive, so "bach
/// dang" finds "Bạch Đằng"). VI primary, EN toggle.
class GlobalTimelineScreen extends ConsumerStatefulWidget {
  const GlobalTimelineScreen({super.key});

  @override
  ConsumerState<GlobalTimelineScreen> createState() =>
      _GlobalTimelineScreenState();
}

class _GlobalTimelineScreenState extends ConsumerState<GlobalTimelineScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

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

    return Scaffold(
      backgroundColor: VSColors.lacquer,
      body: SafeArea(
        bottom: false,
        child: erasAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: VSColors.gold),
          ),
          error: (e, _) => Center(child: Text('$e', style: VSType.bodySmall)),
          data: (eras) {
            final totalEvents =
                eras.fold<int>(0, (sum, e) => sum + e.events.length);

            // Filter: match each event's own text and its era/dynasty context,
            // both folded to remove diacritics so an unaccented query still
            // hits. An era-level match surfaces all of that era's events.
            final query = _foldSearch(_query.trim());
            final filtering = query.isNotEmpty;
            final matches = <_EraMatch>[];
            var resultCount = 0;
            if (filtering) {
              for (final era in eras) {
                final eraHay = _eraHaystack(era, periods);
                final hit = <HistoryEvent>[];
                for (final event in era.events) {
                  if (eraHay.contains(query) ||
                      _eventHaystack(era, event).contains(query)) {
                    hit.add(event);
                  }
                }
                if (hit.isNotEmpty) {
                  matches.add(_EraMatch(era, hit));
                  resultCount += hit.length;
                }
              }
            }

            return ListView(
              padding: const EdgeInsets.only(bottom: VSSpacing.xxl),
              children: <Widget>[
                _Header(
                  eraCount: eras.length,
                  eventCount: totalEvents,
                  lang: lang,
                  controller: _controller,
                  filtering: filtering,
                  resultCount: resultCount,
                  onChanged: (v) => setState(() => _query = v),
                  onClear: () {
                    _controller.clear();
                    setState(() => _query = '');
                  },
                ),
                if (!filtering)
                  for (var ei = 0; ei < eras.length; ei++) ...<Widget>[
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
                      isFirst: ei == 0,
                      onTap: () => context.push('/era/${eras[ei].slug}'),
                    ),
                    for (final event in eras[ei].events)
                      _EventEntry(
                        era: eras[ei],
                        event: event,
                        lang: lang,
                        onTap: () => context.push(
                            '/era/${eras[ei].slug}/event/${event.id}'),
                      ),
                  ]
                else if (matches.isEmpty)
                  _EmptyResults(lang: lang, query: _query.trim())
                else
                  for (var mi = 0; mi < matches.length; mi++) ...<Widget>[
                    if (mi == 0 ||
                        matches[mi].era.period != matches[mi - 1].era.period)
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
                        era: matches[mi].era,
                        event: event,
                        lang: lang,
                        onTap: () => context.push(
                            '/era/${matches[mi].era.slug}/event/${event.id}'),
                      ),
                  ],
                if (!filtering || matches.isNotEmpty) const _EndCap(),
              ],
            );
          },
        ),
      ),
    );
  }
}

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
  return _foldSearch(<String>[
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
  ].join(' '));
}

/// Searchable key for one event: its title, summary, displayed year and the
/// names/epithets of the figures who appear in it (both languages).
String _eventHaystack(Era era, HistoryEvent event) {
  final parts = <String>[
    event.title.vi,
    event.title.en ?? '',
    event.summary.vi,
    event.summary.en ?? '',
    event.year.display.vi,
    event.year.display.en ?? '',
  ];
  for (final c in era.charactersFor(event)) {
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

class _Header extends StatelessWidget {
  const _Header({
    required this.eraCount,
    required this.eventCount,
    required this.lang,
    required this.controller,
    required this.filtering,
    required this.resultCount,
    required this.onChanged,
    required this.onClear,
  });

  final int eraCount;
  final int eventCount;
  final Lang lang;
  final TextEditingController controller;
  final bool filtering;
  final int resultCount;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final overline = lang == Lang.vi ? 'NIÊN BIỂU' : 'TIMELINE';
    final title = lang == Lang.vi ? 'Dòng thời gian' : 'The timeline';
    final sub = filtering
        ? (lang == Lang.vi
            ? (resultCount == 1
                ? '1 kết quả'
                : '$resultCount kết quả')
            : (resultCount == 1 ? '1 result' : '$resultCount results'))
        : (lang == Lang.vi
            ? '$eraCount kỷ nguyên · $eventCount sự kiện'
            : '$eraCount eras · $eventCount events');
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          VSSpacing.xl, VSSpacing.sm, VSSpacing.xl, VSSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Builder(
                builder: (context) => CircleIconButton(
                  icon: Icons.arrow_back,
                  onTap: () =>
                      context.canPop() ? context.pop() : context.go('/'),
                ),
              ),
              const Spacer(),
              const LangToggle(),
            ],
          ),
          const SizedBox(height: VSSpacing.lg),
          Text(
            overline,
            style: VSType.overline.copyWith(
              color: VSColors.goldBright,
              letterSpacing: VSType.track(0.3, 10),
              fontSize: 10,
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
            filtering: filtering,
            onChanged: onChanged,
            onClear: onClear,
          ),
        ],
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
    required this.filtering,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final Lang lang;
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
      padding: const EdgeInsets.symmetric(horizontal: VSSpacing.md),
      child: Row(
        children: <Widget>[
          const Icon(Icons.search, size: 18, color: VSColors.gold),
          const SizedBox(width: VSSpacing.sm),
          Expanded(
            child: TextField(
              controller: controller,
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
                contentPadding:
                    const EdgeInsets.symmetric(vertical: VSSpacing.md),
              ),
            ),
          ),
          if (filtering)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClear,
              child: const Padding(
                padding: EdgeInsets.only(left: VSSpacing.sm),
                child: Icon(Icons.close, size: 18, color: VSColors.inkMuted),
              ),
            ),
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
        ? 'Không tìm thấy sự kiện nào cho “$query”.'
        : 'No events found for “$query”.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          VSSpacing.xl, VSSpacing.xxl, VSSpacing.xl, VSSpacing.xxl),
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
          VSSpacing.md, VSSpacing.xl, VSSpacing.xl, VSSpacing.xs),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: <Widget>[
            if (coverPath != null)
              Positioned.fill(
                child: Image.asset(
                  contentAssetKey(coverPath),
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
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
                  VSSpacing.lg, VSSpacing.md, VSSpacing.lg, VSSpacing.md),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    p.kicker.resolve(lang).toUpperCase(),
                    style: VSType.overline.copyWith(
                      color: accent,
                      letterSpacing: VSType.track(0.3, 10),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(p.title.resolve(lang),
                      style: VSType.title.copyWith(fontSize: 20)),
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
                            blurRadius: 12),
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
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    VSSpacing.sm, VSSpacing.lg, VSSpacing.xl, VSSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (peak) ...<Widget>[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.star_rounded,
                              size: 12, color: VSColors.goldBright),
                          const SizedBox(width: 5),
                          Text(
                            'ĐỈNH CAO',
                            style: VSType.overline.copyWith(
                              color: VSColors.goldBright,
                              letterSpacing: VSType.track(0.3, 10),
                              fontSize: 10,
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
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(era.title.resolve(lang),
                              style: VSType.title.copyWith(fontSize: 22)),
                        ),
                        const Icon(Icons.chevron_right,
                            size: 20, color: VSColors.goldBright),
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
    required this.era,
    required this.event,
    required this.lang,
    required this.onTap,
  });

  final Era era;
  final HistoryEvent event;
  final Lang lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _Spine(nodeColor: VSColors.gold, nodeSize: 9, nodeTop: 16),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    VSSpacing.sm, VSSpacing.sm, VSSpacing.xl, VSSpacing.sm),
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
                        ],
                      ),
                    ),
                    const SizedBox(width: VSSpacing.sm),
                    const Icon(Icons.arrow_forward,
                        size: 15, color: VSColors.inkMuted),
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
