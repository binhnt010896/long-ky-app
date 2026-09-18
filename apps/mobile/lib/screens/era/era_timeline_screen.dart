import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../state/providers.dart';
import '../../theme/era_palette_mapping.dart';
import '../../widgets/circle_icon_button.dart';
import '../../widgets/tilted_backdrop.dart';
import 'widgets/timeline_event_card.dart';

/// Era Timeline — the era's events as cards along a gold spine, with a thin
/// reading-progress bar at the top edge that fills as you scroll. Every card
/// reads the same; no per-event highlight tracks the scroll position (it drew
/// the eye and read as confusing).
class EraTimelineScreen extends ConsumerStatefulWidget {
  const EraTimelineScreen({required this.slug, super.key});

  final String slug;

  @override
  ConsumerState<EraTimelineScreen> createState() => _EraTimelineScreenState();
}

class _EraTimelineScreenState extends ConsumerState<EraTimelineScreen> {
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  // Drives only the thin top progress bar (via a ValueNotifier, so it repaints
  // without rebuilding the list). No per-card highlight follows the scroll.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    _progress.value = max <= 0 ? 0.0 : (_scroll.offset / max).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eraAsync = ref.watch(eraProvider(widget.slug));
    final lang = ref.watch(langProvider);

    return Scaffold(
      backgroundColor: VSColors.lacquer,
      body: eraAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: VSColors.gold),
        ),
        error: (e, _) => Center(child: Text('$e', style: VSType.bodySmall)),
        data: (era) {
          return TiltedBackdrop(
            era: era,
            palette: paletteForEra(era),
            // The timeline is a reading surface — a light scrim over the dawn
            // scene lifts text legibility without dulling the art.
            scrim: 0.1,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: <Widget>[
                  _ProgressBar(progress: _progress),
                  _Header(
                      era: era,
                      lang: lang,
                      // Fall back to the era hub when there is nothing to pop
                      // (e.g. arrived here via a stack-replacing `go`).
                      onBack: () => context.canPop()
                          ? context.pop()
                          : context.go('/era/${era.slug}')),
                  Expanded(
                    child: ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(
                          VSSpacing.screenEdge, VSSpacing.md, VSSpacing.xl, 40),
                      itemCount: era.events.length,
                      itemBuilder: (context, i) {
                        final event = era.events[i];
                        return TimelineEventCard(
                          event: event,
                          // Uniform, calm rows: no scroll-tracked highlight. The
                          // spine stays fully lit as one continuous thread.
                          active: false,
                          lit: true,
                          lang: lang,
                          onTap: () => context.push(
                              '/era/${era.slug}/event/${event.id}'),
                        )
                            .animate()
                            .fadeIn(
                                duration: 320.ms,
                                delay: (i * 70).ms,
                                curve: Curves.easeOut)
                            .slideY(
                                begin: 0.12,
                                end: 0,
                                duration: 380.ms,
                                delay: (i * 70).ms,
                                curve: Curves.easeOutCubic);
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The horizontal gold progress spine at the top edge.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});
  final ValueListenable<double> progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 3,
      child: Stack(
        children: <Widget>[
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(color: Color(0x1AF2EAD9)),
            ),
          ),
          ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (context, value, _) {
              return FractionallySizedBox(
                widthFactor: value.clamp(0.02, 1.0),
                alignment: Alignment.centerLeft,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[VSColors.gold, VSColors.goldBright],
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(color: VSColors.goldGlow, blurRadius: 14),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.era, required this.lang, required this.onBack});

  final Era era;
  final Lang lang;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final overline = lang == Lang.vi ? 'DÒNG SỰ KIỆN' : 'THE EVENTS';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          VSSpacing.screenEdge, VSSpacing.md, VSSpacing.screenEdge, VSSpacing.md),
      child: Row(
        children: <Widget>[
          CircleIconButton(icon: Icons.arrow_back, onTap: onBack, size: 34),
          const SizedBox(width: VSSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  overline,
                  style: VSType.overline.copyWith(
                    letterSpacing: VSType.track(0.3, 10),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Hero(
                  tag: 'era-title-${era.slug}',
                  child: Material(
                    type: MaterialType.transparency,
                    child: Text(era.title.resolve(lang), style: VSType.title),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
