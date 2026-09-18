import 'dart:async';

import 'package:core_domain/core_domain.dart';
import 'package:experience/experience.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../state/providers.dart';
import '../../theme/content_assets.dart';
import '../../theme/era_palette_mapping.dart';
import '../../widgets/circle_icon_button.dart';
import '../../widgets/lang_toggle.dart';
import '../era/widgets/era_scene_backdrop.dart';
import 'widgets/chronicle_pull_quote.dart';
import 'widgets/citation_card.dart';
import 'widgets/event_figures.dart';
import 'widgets/expandable_details.dart';

/// Event Detail — the parallax hero image slot, the event body, the italic
/// chronicle pull-quote, and the visible source citation. VI primary, EN toggle.
class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({required this.slug, required this.eventId, super.key});

  final String slug;
  final String eventId;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  final ParallaxController _pointer = ParallaxController();
  TiltParallaxDriver? _tilt;
  PageController? _pageController;
  int? _index;
  bool _showHint = true;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    if (ref.read(tierProvider).capabilities.tilt) {
      _tilt = TiltParallaxDriver(_pointer)..start();
    }
    // Auto-dismiss the swipe hint after a few seconds. Cancelled on dispose so
    // no timer is left pending.
    _hintTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showHint = false);
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _tilt?.dispose();
    _pointer.dispose();
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final erasAsync = ref.watch(erasProvider);
    final lang = ref.watch(langProvider);

    return Scaffold(
      backgroundColor: VSColors.lacquer,
      body: erasAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: VSColors.gold),
        ),
        error: (e, _) => Center(child: Text('$e', style: VSType.bodySmall)),
        data: (eras) {
          // One continuous chronological sequence across every era: eras are
          // already sorted by order, and each era's events by order, so the
          // reader can swipe from an era's last event straight into the next
          // era's first — the timeline never dead-ends at a chapter boundary.
          final entries = <_PagerEntry>[
            for (final era in eras)
              for (var j = 0; j < era.events.length; j++)
                _PagerEntry(
                  era: era,
                  event: era.events[j],
                  eraPos: j + 1,
                  eraCount: era.events.length,
                ),
          ];
          if (entries.isEmpty) return const SizedBox.shrink();

          final found = entries.indexWhere((e) =>
              e.era.slug == widget.slug && e.event.id == widget.eventId);
          final startIndex = found < 0 ? 0 : found;
          _pageController ??= PageController(initialPage: startIndex);
          _index ??= startIndex;
          final index = _index!.clamp(0, entries.length - 1);
          final current = entries[index];
          final canSwipe = entries.length > 1;

          return Stack(
            children: <Widget>[
              // Horizontal pager over the whole corpus. Standard direction: a
              // swipe LEFT advances to the next event (it slides in from the
              // right), a swipe RIGHT goes back. Each page scrolls vertically.
              PageView.builder(
                controller: _pageController,
                reverse: false,
                physics: canSwipe
                    ? const PageScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                itemCount: entries.length,
                onPageChanged: (i) {
                  _hintTimer?.cancel();
                  setState(() {
                    _index = i;
                    _showHint = false;
                  });
                },
                itemBuilder: (context, i) => _EventPage(
                  era: entries[i].era,
                  event: entries[i].event,
                  palette: paletteForEra(entries[i].era),
                  pointer: _pointer,
                  lang: lang,
                ),
              ),
              // Fixed chrome over the hero. The counter is era-relative, so it
              // resets as you cross into a new chapter.
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: VSSpacing.xl)
                      .add(const EdgeInsets.only(top: VSSpacing.xs)),
                  child: Row(
                    children: <Widget>[
                      CircleIconButton(
                        icon: Icons.arrow_back,
                        // Up-navigate to the timeline of the era currently on
                        // screen — not a plain pop, which (after swiping across
                        // an era boundary) would return to the origin era.
                        onTap: () => context
                            .go('/era/${current.era.slug}/timeline'),
                      ),
                      const Spacer(),
                      Text(
                        '${_two(current.eraPos)} / ${_two(current.eraCount)}',
                        style: VSType.caption.copyWith(
                          color: VSColors.inkSecondary,
                          letterSpacing: VSType.track(0.28, 11),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: VSSpacing.md),
                      const LangToggle(),
                    ],
                  ),
                ),
              ),
              if (canSwipe) _SwipeHint(visible: _showHint, lang: lang),
            ],
          );
        },
      ),
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}

/// One page in the continuous cross-era pager: the event, its owning era (for
/// palette/backdrop/figures), and the event's position within that era (for the
/// era-relative counter).
@immutable
class _PagerEntry {
  const _PagerEntry({
    required this.era,
    required this.event,
    required this.eraPos,
    required this.eraCount,
  });

  final Era era;
  final HistoryEvent event;
  final int eraPos;
  final int eraCount;
}

/// One event's page within the pager: the hero slot plus the scrolling body.
class _EventPage extends StatelessWidget {
  const _EventPage({
    required this.era,
    required this.event,
    required this.palette,
    required this.pointer,
    required this.lang,
  });

  final Era era;
  final HistoryEvent event;
  final VSEraPalette palette;
  final ParallaxController pointer;
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        _EventHero(
          era: era,
          event: event,
          palette: palette,
          pointer: pointer,
          lang: lang,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              VSSpacing.xl, VSSpacing.xl, VSSpacing.xl, 40),
          child: _EventBody(era: era, event: event, lang: lang),
        ),
      ],
    );
  }
}

/// The one-time affordance telling the user the detail is swipeable. Fades out
/// on the first swipe or after a few seconds.
class _SwipeHint extends StatelessWidget {
  const _SwipeHint({required this.visible, required this.lang});

  final bool visible;
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    final label =
        lang == Lang.vi ? 'Vuốt để chuyển sự kiện' : 'Swipe to browse events';
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        child: IgnorePointer(
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            child: Padding(
              padding: const EdgeInsets.only(bottom: VSSpacing.lg),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: VSSpacing.md, vertical: VSSpacing.sm),
                  decoration: BoxDecoration(
                    color: VSColors.lacquerVoid.withValues(alpha: 0.62),
                    borderRadius: VSRadii.pillAll,
                    border: Border.all(color: VSColors.goldBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.chevron_left,
                          size: 18, color: VSColors.goldBright),
                      const SizedBox(width: VSSpacing.xs),
                      Text(
                        label,
                        style: VSType.caption.copyWith(
                          color: VSColors.inkSecondary,
                          letterSpacing: VSType.track(0.1, 12),
                        ),
                      ),
                      const SizedBox(width: VSSpacing.xs),
                      const Icon(Icons.chevron_right,
                          size: 18, color: VSColors.goldBright),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The hero illustration slot — a parallax scene today, a real sơn mài
/// illustration when [event] gains a `hero.flagship` asset. Fixed height, fades
/// into the body sheet, with the provenance caption seated at the bottom.
class _EventHero extends StatelessWidget {
  const _EventHero({
    required this.era,
    required this.event,
    required this.palette,
    required this.pointer,
    required this.lang,
  });

  final Era era;
  final HistoryEvent event;
  final VSEraPalette palette;
  final ParallaxController pointer;
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    final caption = event.hero?.caption ?? era.cover?.caption;
    final hero = event.hero;
    // Tier-aware: the flagship tier plays the (possibly animated) primary; the
    // reduced/trailer tiers use the static fallback. For a still hero the two
    // paths are identical, so this only matters for an animated set-piece where
    // `flagship` is a looping WebP and `reduced` its static PNG.
    final heroPath = hero == null || hero.isPlaceholder
        ? null
        : (context.caps.rive
            ? (hero.flagship ?? hero.reduced)
            : (hero.reduced ?? hero.flagship));

    return SizedBox(
      height: 356,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Real hero illustration when present; otherwise the era's parallax
          // scene stands in.
          if (heroPath != null)
            Image.asset(
              contentAssetKey(heroPath),
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.medium,
              frameBuilder: fadeInImageFrame,
              errorBuilder: (_, __, ___) => EraSceneBackdrop(
                era: era,
                pointer: pointer,
                palette: palette,
                vignette: false,
              ),
            )
          else
            EraSceneBackdrop(
              era: era,
              pointer: pointer,
              palette: palette,
              vignette: false,
            ),
          // Fade the hero into the body sheet.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0x66060D0C),
                  Color(0x00060D0C),
                  Color(0xD9060D0C),
                  Color(0xFF07100F),
                ],
                stops: <double>[0, 0.3, 0.9, 1],
              ),
            ),
          ),
          if (caption != null)
            Positioned(
              left: VSSpacing.screenEdge,
              bottom: 60,
              child: Row(
                children: <Widget>[
                  Transform.rotate(
                    angle: 0.785398,
                    child: Container(width: 5, height: 5, color: VSColors.gold),
                  ),
                  const SizedBox(width: VSSpacing.sm - 2),
                  Text(caption.resolve(lang), style: VSType.provenance),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EventBody extends StatelessWidget {
  const _EventBody({required this.era, required this.event, required this.lang});

  final Era era;
  final HistoryEvent event;
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    final section = era.primarySource.section?.resolve(lang);
    final figures = era.charactersFor(event);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // meta: year — section
        Row(
          children: <Widget>[
            Text(
              event.year.display.resolve(lang),
              style: VSType.label.copyWith(
                color: VSColors.goldBright,
                fontSize: 12,
                letterSpacing: VSType.track(0.14, 12),
              ),
            ),
            if (section != null) ...<Widget>[
              const SizedBox(width: VSSpacing.sm),
              Container(width: 20, height: 1, color: VSColors.goldBorder),
              const SizedBox(width: VSSpacing.sm),
              Text(
                section,
                style: VSType.caption.copyWith(
                  color: VSColors.inkMuted,
                  letterSpacing: VSType.track(0.14, 11),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: VSSpacing.sm + 2),
        Text(event.title.resolve(lang), style: VSType.headline),
        if (event.body != null) ...<Widget>[
          const SizedBox(height: VSSpacing.lg),
          Text(
            event.body!.resolve(lang),
            style: VSType.body.copyWith(color: VSColors.inkBody),
          ),
        ],
        if (event.details != null) ...<Widget>[
          const SizedBox(height: VSSpacing.md),
          ExpandableDetails(details: event.details!, lang: lang),
        ],
        if (event.pullQuote != null) ...<Widget>[
          const SizedBox(height: VSSpacing.xl),
          ChroniclePullQuote(quote: event.pullQuote!, lang: lang),
        ],
        if (figures.isNotEmpty) ...<Widget>[
          const SizedBox(height: VSSpacing.xl),
          EventFigures(figures: figures, slug: era.slug, lang: lang),
        ],
        const SizedBox(height: VSSpacing.xl),
        CitationCard(citation: event.citation, lang: lang),
      ],
    );
  }
}
