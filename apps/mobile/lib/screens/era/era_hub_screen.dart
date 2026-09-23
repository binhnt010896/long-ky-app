import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../state/media_prefetch.dart';
import '../../state/providers.dart';
import '../../theme/era_palette_mapping.dart';
import '../../widgets/circle_icon_button.dart';
import '../../widgets/lang_toggle.dart';
import '../../widgets/tilted_backdrop.dart';
import '../event/widgets/event_figures.dart';

/// Era Hub — the era's home. A parallax hero (kicker, title, span, tagline)
/// opening onto a scroll that answers *who* and *why*: an editorial intro, the
/// chronicle it is drawn from, and the era's key figures — then the CTA into the
/// chronological timeline (the *when*). VI primary, EN toggle.
class EraHubScreen extends ConsumerWidget {
  const EraHubScreen({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eraAsync = ref.watch(eraProvider(slug));
    final lang = ref.watch(langProvider);

    // Warm this era's event/figure art and its cover video in the background
    // as soon as it loads — cheap to repeat (cache-checked) on later rebuilds
    // (e.g. the VI/EN toggle), so no extra guard is needed.
    eraAsync.whenData((era) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => MediaPrefetcher.instance.queue(eraHubMediaFor(era)));
    });

    return Scaffold(
      backgroundColor: VSColors.lacquer,
      body: eraAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: VSColors.gold),
        ),
        error: (e, _) => Center(child: Text('$e', style: VSType.bodySmall)),
        data: (era) => TiltedBackdrop(
          era: era,
          palette: paletteForEra(era),
          allowVideo: true,
          child: SafeArea(
            bottom: false,
            child: Stack(
              children: <Widget>[
                // The whole hub scrolls over the fixed parallax scene: hero band
                // first, then the era-home facets on a dark reading sheet.
                ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    _HubHero(era: era, lang: lang),
                    _HubBody(
                      era: era,
                      lang: lang,
                      onExplore: () =>
                          context.push('/era/${era.slug}/timeline'),
                    ),
                  ],
                ),
                // Pinned chrome over the hero.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: VSSpacing.xl)
                      .add(const EdgeInsets.only(top: VSSpacing.sm)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      CircleIconButton(
                        icon: Icons.arrow_back,
                        // Up-navigate to the era list (Home) when there is
                        // nothing to pop — e.g. after arriving here via a
                        // stack-replacing `go` from event detail / timeline.
                        onTap: () =>
                            context.canPop() ? context.pop() : context.go('/'),
                      ),
                      Row(
                        children: <Widget>[
                          CircleIconButton(
                            icon: Icons.map_outlined,
                            onTap: () => context.push('/map?era=${era.slug}'),
                          ),
                          const SizedBox(width: VSSpacing.sm),
                          const LangToggle(),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HubHero extends StatelessWidget {
  const _HubHero({required this.era, required this.lang});

  final Era era;
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    // A tall band so the era lands as a "chapter cover" before the sheet.
    final height = MediaQuery.sizeOf(context).height * 0.62;
    return SizedBox(
      height: height,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: VSSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                era.kicker.resolve(lang).toUpperCase(),
                style: VSType.kicker,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: VSSpacing.lg),
              Hero(
                tag: 'era-title-${era.slug}',
                child: Material(
                  type: MaterialType.transparency,
                  child: Text(
                    era.title.resolve(lang),
                    style: VSType.hub.copyWith(
                      shadows: const <Shadow>[
                        Shadow(
                            color: Color(0x99000000),
                            blurRadius: 26,
                            offset: Offset(0, 2)),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: VSSpacing.lg),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(width: 24, height: 1, color: VSColors.gold),
                  const SizedBox(width: VSSpacing.sm + 2),
                  Text(era.yearRange.display.resolve(lang), style: VSType.label),
                  const SizedBox(width: VSSpacing.sm + 2),
                  Container(width: 24, height: 1, color: VSColors.gold),
                ],
              ),
              const SizedBox(height: VSSpacing.lg),
              Text(
                era.subtitle.resolve(lang),
                style: VSType.subtitleItalic,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: VSSpacing.xl),
              const _ScrollCue(),
            ],
          ),
        ),
      ),
    );
  }
}

/// A faint "scroll for more" affordance seated under the hero.
class _ScrollCue extends StatelessWidget {
  const _ScrollCue();

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.keyboard_arrow_down,
      size: 26,
      color: VSColors.gold.withValues(alpha: 0.7),
    );
  }
}

/// The era-home sheet below the hero: editorial intro, chronicle provenance,
/// the roster of figures, and the CTA into the timeline.
class _HubBody extends StatelessWidget {
  const _HubBody({
    required this.era,
    required this.lang,
    required this.onExplore,
  });

  final Era era;
  final Lang lang;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    const sheet = Color(0xF2060D0C);
    return Column(
      children: <Widget>[
        // Fade the scene into the reading sheet.
        Container(
          height: 72,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0x00060D0C), sheet],
            ),
          ),
        ),
        Container(
          color: sheet,
          padding: const EdgeInsets.fromLTRB(
              VSSpacing.xl, 0, VSSpacing.xl, VSSpacing.huge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (era.overview != null) ...<Widget>[
                Text(
                  era.overview!.resolve(lang),
                  style: VSType.body.copyWith(color: VSColors.inkBody),
                ),
                const SizedBox(height: VSSpacing.xl),
              ],
              _ChronicleCard(source: era.primarySource, lang: lang),
              if (era.characters.isNotEmpty) ...<Widget>[
                const SizedBox(height: VSSpacing.xl),
                EventFigures(figures: era.characters, slug: era.slug, lang: lang),
              ],
              const SizedBox(height: VSSpacing.xxl),
              _ExploreButton(era: era, lang: lang, onTap: onExplore),
            ],
          ),
        ),
      ],
    );
  }
}

/// The single chronicle this era is drawn from — provenance, made visible.
class _ChronicleCard extends StatelessWidget {
  const _ChronicleCard({required this.source, required this.lang});

  final Citation source;
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    final label = lang == Lang.vi ? 'BỘ CHÍNH SỬ' : 'THE CHRONICLE';
    final section = source.section?.resolve(lang);
    final meta = <String>[
      if (section != null) section,
      if (source.author != null) source.author!,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: VSSpacing.md, vertical: VSSpacing.md),
      decoration: BoxDecoration(
        color: VSColors.inkPrimary.withValues(alpha: 0.03),
        borderRadius: VSRadii.cardAll,
        border: Border.all(color: VSColors.goldBorder),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.auto_stories, size: 20, color: VSColors.goldBright),
          const SizedBox(width: VSSpacing.md - 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: VSType.overline.copyWith(
                    color: VSColors.goldBright,
                    letterSpacing: VSType.track(0.34, 10),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(source.work, style: VSType.cardTitle.copyWith(fontSize: 15)),
                if (meta.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    style: VSType.caption.copyWith(
                      color: VSColors.inkMuted,
                      letterSpacing: VSType.track(0.14, 11),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExploreButton extends StatelessWidget {
  const _ExploreButton({
    required this.era,
    required this.lang,
    required this.onTap,
  });

  final Era era;
  final Lang lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = era.events.length;
    final ctaLabel = lang == Lang.vi ? 'Xem dòng sự kiện' : 'Explore the events';
    final count = lang == Lang.vi
        ? '$n sự kiện · 1 bộ chính sử'
        : '$n events · 1 chronicle';

    return Column(
      children: <Widget>[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  VSColors.goldBright.withValues(alpha: 0.16),
                  VSColors.gold.withValues(alpha: 0.10),
                ],
              ),
              borderRadius: VSRadii.pillAll,
              border: Border.all(color: VSColors.gold.withValues(alpha: 0.6)),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                    color: Color(0x66000000), blurRadius: 30, offset: Offset(0, 8)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  ctaLabel,
                  style: VSType.label.copyWith(
                    color: VSColors.inkPrimary,
                    letterSpacing: VSType.track(0.14, 14),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: VSSpacing.sm + 2),
                const Icon(Icons.arrow_forward,
                    size: 16, color: VSColors.goldBright),
              ],
            ),
          ),
        ),
        const SizedBox(height: VSSpacing.md),
        Text(
          count.toUpperCase(),
          style: VSType.caption.copyWith(
            letterSpacing: VSType.track(0.24, 11),
            fontSize: 11,
            color: VSColors.inkFaint,
          ),
        ),
      ],
    );
  }
}
