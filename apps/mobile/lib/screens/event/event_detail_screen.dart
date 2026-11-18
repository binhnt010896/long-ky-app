import 'dart:async';

import 'package:core_domain/core_domain.dart';
import 'package:experience/experience.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../app_router.dart' show routeTelemetryObserverProvider;
import '../../feedback/feedback.dart';
import '../../state/onboarding_store.dart' show kSwipeHintShows;
import '../../state/providers.dart';
import '../../state/visit_store.dart';
import '../../telemetry/reading_depth.dart';
import '../../telemetry/route_telemetry.dart' show RouteTelemetryObserver;
import '../sanh/disclaimer_screen.dart' show DisclaimerInfoButton;
import '../../theme/content_assets.dart';
import '../../theme/era_palette_mapping.dart';
import '../streets/street_reverse_chip.dart';
import '../../widgets/circle_icon_button.dart';
import '../../widgets/lang_toggle.dart';
import '../../widgets/load_error_view.dart';
import '../../widgets/narration_button.dart';
import '../../widgets/pressable.dart';
import '../../state/narration_controller.dart';
import '../era/widgets/era_scene_backdrop.dart';
import '../../widgets/unlock/art_gate.dart';
import '../../widgets/unlock/mystery_art.dart';
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
  bool _showHint = false;
  Timer? _hintTimer;

  /// A swipe changes the event on screen but not the route, so each one is
  /// reported to the screen-view observer itself — see
  /// [RouteTelemetryObserver.showInPlace].
  RouteTelemetryObserver? _telemetryObserver;
  String? _inPlaceLocation;

  @override
  void initState() {
    super.initState();
    if (ref.read(tierProvider).capabilities.tilt) {
      _tilt = TiltParallaxDriver(_pointer)..start();
    }
    // The swipe hint is a lesson, not chrome: it shows on the first few opens
    // only (the "next event" card at the foot of every page is the standing
    // affordance). Auto-dismissed after a few seconds; the timer is cancelled
    // on dispose so none is left pending.
    if (ref.read(swipeHintCountProvider) < kSwipeHintShows) {
      _showHint = true;
      _hintTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _showHint = false);
      });
      // Provider state must not change while the tree is building.
      Future<void>.microtask(() {
        if (!mounted) return;
        ref.read(swipeHintCountProvider.notifier).state++;
        ref.read(onboardingStoreProvider).markSwipeHintShown();
      });
    }
  }

  /// Back returns to wherever the reader came from — search results, a
  /// figure's page, the quiz, an era's event list. The one exception: they
  /// came from an era's own pages and have since swiped into a *different*
  /// era, where the list underneath no longer holds what they are reading —
  /// then back goes up to the timeline of the era now on screen.
  void _back(Era current) {
    final router = GoRouter.of(context);
    final crossed = current.slug != widget.slug;
    if (router.canPop() && !(crossed && _cameFromEraPage(router))) {
      router.pop();
    } else {
      router.go('/era/${current.slug}/timeline');
    }
  }

  /// Whether the page under this one is an era page (hub or event list).
  static bool _cameFromEraPage(GoRouter router) {
    final matches = router.routerDelegate.currentConfiguration.matches;
    if (matches.length < 2) return true;
    return matches[matches.length - 2].matchedLocation.startsWith('/era/');
  }

  void _goTo(int index) {
    final controller = _pageController;
    if (controller == null || !controller.hasClients) return;
    if (MediaQuery.of(context).disableAnimations) {
      controller.jumpToPage(index);
    } else {
      controller.animateToPage(
        index,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void dispose() {
    final location = _inPlaceLocation;
    if (location != null) _telemetryObserver?.clearInPlace(location);
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
        error: (e, _) => LoadErrorView(
          error: e,
          onRetry: () => ref.invalidate(erasProvider),
        ),
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
                  final observer = ref.read(routeTelemetryObserverProvider);
                  _telemetryObserver = observer;
                  _inPlaceLocation = observer.showInPlace((
                    name: 'event_detail',
                    params: <String, Object>{
                      'era_slug': entries[i].era.slug,
                      'event_id': entries[i].event.id,
                      'via': 'swipe',
                    },
                  ));
                  // A swipe opens the event as surely as a tap does, but the
                  // route (which the visit recorder watches) has not changed.
                  ref
                      .read(visitedProvider.notifier)
                      .record(
                        VisitKey.event(entries[i].event.id),
                        reading: LastRead(
                          eraSlug: entries[i].era.slug,
                          eventId: entries[i].event.id,
                        ),
                      )
                      .catchError((Object _) {});
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
                  current: i == index,
                  previous: i > 0 ? entries[i - 1] : null,
                  next: i < entries.length - 1 ? entries[i + 1] : null,
                  onPrevious: () => _goTo(i - 1),
                  onNext: () => _goTo(i + 1),
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
                      CircleIconButton.back(
                        onTap: () => _back(current.era),
                      ),
                      const Spacer(),
                      Semantics(
                        label: lang == Lang.vi
                            ? 'Sự kiện ${current.eraPos} trên ${current.eraCount}'
                            : 'Event ${current.eraPos} of ${current.eraCount}',
                        excludeSemantics: true,
                        child: Text(
                          '${_two(current.eraPos)} / ${_two(current.eraCount)}',
                          maxLines: 1,
                          softWrap: false,
                          style: VSType.caption.copyWith(
                            color: VSColors.inkSecondary,
                            letterSpacing: VSType.track(0.28, 11),
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: VSSpacing.sm),
                      // The event on screen now, not the one the pager opened
                      // on — a swipe changes the page but not the route.
                      NarrationButton(
                        kind: NarrationKind.event,
                        id: current.event.id,
                      ),
                      FeedbackButton(
                        target: FeedbackTarget(
                          type: 'event',
                          id: current.event.id,
                          title: current.event.title.resolve(Lang.vi),
                          route: '/era/${current.era.slug}/event/'
                              '${current.event.id}',
                        ),
                      ),
                      const SizedBox(width: VSSpacing.xxs),
                      const LangToggle(compact: true),
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
    required this.current,
    required this.previous,
    required this.next,
    required this.onPrevious,
    required this.onNext,
  });

  final Era era;
  final HistoryEvent event;
  final VSEraPalette palette;
  final ParallaxController pointer;
  final Lang lang;

  /// The page on screen (not a neighbour sliding in or out mid-swipe).
  final bool current;

  /// The neighbours in the cross-era sequence (null at either end).
  final _PagerEntry? previous;
  final _PagerEntry? next;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return EventReadingDepth(
      eventId: event.id,
      current: current,
      child: _list(),
    );
  }

  Widget _list() {
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
              VSSpacing.xl, VSSpacing.xl, VSSpacing.xl, VSSpacing.xl),
          child: EventBody(
            event: event,
            figures: era.charactersFor(event),
            figureSlug: era.slug,
            section: era.primarySource.section?.resolve(lang),
            lang: lang,
          ),
        ),
        _PagerNav(
          era: era,
          previous: previous,
          next: next,
          lang: lang,
          onPrevious: onPrevious,
          onNext: onNext,
        ),
      ],
    );
  }
}

/// Where the page leads once it has been read: a card for the next event (it
/// names the next era when the sequence crosses into one) and a quiet link
/// back to the previous. Tapping either turns the pager, exactly as a swipe.
class _PagerNav extends StatelessWidget {
  const _PagerNav({
    required this.era,
    required this.previous,
    required this.next,
    required this.lang,
    required this.onPrevious,
    required this.onNext,
  });

  final Era era;
  final _PagerEntry? previous;
  final _PagerEntry? next;
  final Lang lang;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final vi = lang == Lang.vi;
    final n = next;
    final p = previous;
    return Padding(
      padding: EdgeInsets.fromLTRB(VSSpacing.xl, 0, VSSpacing.xl,
          40 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (n != null)
            Pressable(
              key: const ValueKey<String>('event-next'),
              onTap: onNext,
              child: Container(
                padding: const EdgeInsets.all(VSSpacing.md),
                decoration: BoxDecoration(
                  color: VSColors.goldWash,
                  borderRadius: VSRadii.cardAll,
                  border:
                      Border.all(color: VSColors.gold.withValues(alpha: 0.45)),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            n.era.slug == era.slug
                                ? (vi ? 'SỰ KIỆN TIẾP THEO' : 'NEXT EVENT')
                                : (vi
                                    ? 'SANG ${n.era.title.resolve(lang).toUpperCase()}'
                                    : 'ON TO ${n.era.title.resolve(lang).toUpperCase()}'),
                            style: VSType.overline
                                .copyWith(color: VSColors.goldBright),
                          ),
                          const SizedBox(height: VSSpacing.xs),
                          Text(n.event.title.resolve(lang),
                              style: VSType.cardTitle),
                          const SizedBox(height: 2),
                          Text(
                            n.event.year.display.resolve(lang),
                            style:
                                VSType.caption.copyWith(color: VSColors.gold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: VSSpacing.md),
                    const Icon(Icons.arrow_forward,
                        size: 20, color: VSColors.goldBright),
                  ],
                ),
              ),
            ),
          if (p != null)
            Pressable(
              key: const ValueKey<String>('event-previous'),
              onTap: onPrevious,
              minSize: kMinTapTarget,
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: VSSpacing.xs),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.arrow_back,
                        size: 16, color: VSColors.inkMuted),
                    const SizedBox(width: VSSpacing.xs),
                    Expanded(
                      child: Text(
                        '${vi ? 'Trước' : 'Previous'}: '
                        '${p.event.title.resolve(lang)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: VSType.caption
                            .copyWith(color: VSColors.inkSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
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
            ArtGate(
              visitKey: VisitKey.event(event.id),
              kind: MysteryKind.hero,
              interactive: false,
              child: Image(
                image: contentImageProvider(heroPath),
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
          // Above the fade, which would otherwise swallow the tap.
          UnlockAffordance(
            visitKey: VisitKey.event(event.id),
            alignment: const Alignment(0, 0.5),
          ),
          if (caption != null)
            Positioned(
              left: VSSpacing.screenEdge,
              right: VSSpacing.screenEdge,
              bottom: 60,
              child: Row(
                children: <Widget>[
                  Transform.rotate(
                    angle: 0.785398,
                    child: Container(width: 5, height: 5, color: VSColors.gold),
                  ),
                  const SizedBox(width: VSSpacing.sm - 2),
                  // Bounded, so the ⓘ never pushes the row off a narrow
                  // screen: a long caption wraps instead.
                  Flexible(
                    child:
                        Text(caption.resolve(lang), style: VSType.provenance),
                  ),
                  const DisclaimerInfoButton(),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The scrolling body under an event's hero: year line, title, body, details,
/// pull-quote, figures, street chip and citation. Shared by the in-era page and
/// the standalone page — the only differences are the optional [section] line
/// (an era's source section) and where a figure chip leads ([figureSlug]).
class EventBody extends StatelessWidget {
  const EventBody({
    required this.event,
    required this.figures,
    required this.figureSlug,
    required this.lang,
    this.section,
    this.figureSlugFor,
    super.key,
  });

  final HistoryEvent event;
  final List<Character> figures;

  /// Era slug used for figure chips (overridden per figure by [figureSlugFor]).
  final String figureSlug;
  final String Function(Character)? figureSlugFor;
  final String? section;
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        UnlockPrompt(visitKey: VisitKey.event(event.id)),
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
              Expanded(
                child: Text(
                  section!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: VSType.caption.copyWith(
                    color: VSColors.inkMuted,
                    letterSpacing: VSType.track(0.14, 11),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: VSSpacing.sm + 2),
        Text(event.title.resolve(lang), style: VSType.headline),
        if (event.body != null) ...<Widget>[
          const SizedBox(height: VSSpacing.lg),
          Text(event.body!.resolve(lang), style: VSType.reading),
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
          EventFigures(
              figures: figures,
              slug: figureSlug,
              slugFor: figureSlugFor,
              lang: lang),
        ],
        StreetReverseChip(type: StreetTargetType.event, id: event.id),
        const SizedBox(height: VSSpacing.xl),
        CitationCard(citation: event.citation, lang: lang),
      ],
    );
  }
}
