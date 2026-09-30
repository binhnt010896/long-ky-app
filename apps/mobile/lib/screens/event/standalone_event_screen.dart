import 'package:core_domain/core_domain.dart';
import 'package:experience/experience.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../state/providers.dart';
import '../../theme/content_assets.dart';
import '../../widgets/circle_icon_button.dart';
import '../../widgets/lang_toggle.dart';
import 'event_detail_screen.dart' show EventBody;

/// A standalone event — one that no era lists (Cycle N). The same body,
/// pull-quote, figures and citation as an in-era event, but no era scene: a
/// neutral lacquer ground and the event's own hero instead, and no "3 / 12"
/// counter or pager (there are no neighbours to swipe to).
///
/// `/su-kien/:id` only builds this for a standalone event — an event that sits
/// in an era is redirected to `/era/:slug/event/:id` before it gets here.
class StandaloneEventScreen extends ConsumerWidget {
  const StandaloneEventScreen({required this.eventId, super.key});

  final String eventId;

  static const String viLabel = 'SỰ KIỆN RIÊNG';
  static const String enLabel = 'STANDALONE EVENT';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    final location = ref.watch(eventLocationProvider(eventId));
    final people = ref.watch(peopleProvider).valueOrNull;
    final home = ref.watch(homeEraSlugsProvider).valueOrNull;

    return Scaffold(
      backgroundColor: VSColors.lacquer,
      body: location.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: VSColors.gold),
        ),
        error: (e, _) => Center(child: Text('$e', style: VSType.bodySmall)),
        data: (found) {
          if (found == null) return _NotFound(lang: lang);
          final event = found.event;
          // Only people who appear on some era's roster get a chip: every
          // chip has to open a page (N3 guarantees this for authored events;
          // this just keeps a stale id from drawing a dead tile).
          final figures = <Character>[
            for (final id in event.figureIds)
              if (people?[id] != null && home?[id] != null) people![id]!,
          ];
          return Stack(
            children: <Widget>[
              ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  _StandaloneHero(event: event, lang: lang),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        VSSpacing.xl, VSSpacing.xl, VSSpacing.xl, 40),
                    child: EventBody(
                      event: event,
                      figures: figures,
                      figureSlug: '',
                      figureSlugFor: (c) => home?[c.id] ?? '',
                      lang: lang,
                    ),
                  ),
                ],
              ),
              SafeArea(child: _TopBar(lang: lang)),
            ],
          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.lang});

  final Lang lang;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: VSSpacing.xl)
          .add(const EdgeInsets.only(top: VSSpacing.xs)),
      child: Row(
        children: <Widget>[
          CircleIconButton(
            icon: Icons.arrow_back,
            onTap: () => context.canPop() ? context.pop() : context.go('/'),
          ),
          // Flexible: this label is wider than the era page's "03 / 12", and on
          // a narrow phone it must shrink (ellipsis) rather than overflow.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: VSSpacing.md),
              child: Text(
                lang == Lang.vi
                    ? StandaloneEventScreen.viLabel
                    : StandaloneEventScreen.enLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: VSType.caption.copyWith(
                  color: VSColors.inkSecondary,
                  letterSpacing: VSType.track(0.2, 11),
                  fontSize: 11,
                ),
              ),
            ),
          ),
          const SizedBox(width: VSSpacing.md),
          const LangToggle(),
        ],
      ),
    );
  }
}

/// The event's own hero over a neutral lacquer ground (no era scene to borrow).
class _StandaloneHero extends StatelessWidget {
  const _StandaloneHero({required this.event, required this.lang});

  final HistoryEvent event;
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    final hero = event.hero;
    final caption = hero?.caption;
    // Tier-aware, same rule as an in-era hero: flagship plays the (possibly
    // animated) primary, the reduced tiers use the static fallback.
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
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[VSColors.lacquerVoid, VSColors.lacquer],
              ),
            ),
          ),
          if (heroPath != null)
            Image(
              image: contentImageProvider(heroPath),
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.medium,
              frameBuilder: fadeInImageFrame,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
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

class _NotFound extends StatelessWidget {
  const _NotFound({required this.lang});

  final Lang lang;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(VSSpacing.xl),
            child: CircleIconButton(
              icon: Icons.arrow_back,
              onTap: () => context.canPop() ? context.pop() : context.go('/'),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                lang == Lang.vi
                    ? 'Không tìm thấy sự kiện này.'
                    : 'This event could not be found.',
                style: VSType.body.copyWith(color: VSColors.inkSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
