import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../era/widgets/era_scene_backdrop.dart';
import '../../../theme/era_palette_mapping.dart';

/// One full-bleed era page in the Home stack: the shared parallax backdrop plus
/// the home hero copy (bottom-left). Works at every tier.
class EraSceneView extends StatelessWidget {
  const EraSceneView({
    required this.era,
    required this.pointer,
    required this.lang,
    super.key,
  });

  final Era era;

  /// Shared parallax pointer (held at rest on non-tilt tiers).
  final ValueListenable<Offset> pointer;

  final Lang lang;

  @override
  Widget build(BuildContext context) {
    final palette = paletteForEra(era);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Home shows the ridge foreground; keep the vignette bottom light and
        // seat the hero copy on its own local scrim instead.
        EraSceneBackdrop(
          era: era,
          pointer: pointer,
          palette: palette,
          foregroundVisible: true,
        ),
        // Flat dim mask over the whole scene, so the kicker line (which sits
        // where _HeroScrim's gradient has already faded toward the brighter
        // art) stays legible too, not just the title lower in the scrim.
        const IgnorePointer(
          child: ColoredBox(color: Color.fromRGBO(0, 0, 0, 0.1)),
        ),
        const IgnorePointer(child: _HeroScrim()),
        _EraHero(era: era, lang: lang),
      ],
    );
  }
}

/// A bottom-left-weighted darkening behind the hero copy, so text stays legible
/// while the ridge peaks to the centre/right stay bright.
class _HeroScrim extends StatelessWidget {
  const _HeroScrim();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment(0.7, -0.25),
          colors: <Color>[Color(0xDB060D0C), Color(0x00060D0C)],
          stops: <double>[0.0, 0.62],
        ),
      ),
    );
  }
}

class _EraHero extends StatelessWidget {
  const _EraHero({required this.era, required this.lang});

  final Era era;
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(VSSpacing.xxl, 0, 56, 118),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (era.flagship) ...<Widget>[
              const _FlagshipBadge(),
              const SizedBox(height: VSSpacing.md),
            ],
            Text(era.kicker.resolve(lang).toUpperCase(), style: VSType.kicker),
            const SizedBox(height: VSSpacing.md),
            Hero(
              tag: 'era-title-${era.slug}',
              child: Material(
                type: MaterialType.transparency,
                child: Text(
                  era.title.resolve(lang),
                  style: VSType.hero.copyWith(
                    shadows: const <Shadow>[
                      Shadow(
                          color: Color(0x99000000),
                          blurRadius: 24,
                          offset: Offset(0, 2)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: VSSpacing.lg),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(width: 26, height: 1, color: VSColors.gold),
                const SizedBox(width: VSSpacing.sm + 2),
                Text(era.yearRange.display.resolve(lang), style: VSType.label),
              ],
            ),
            const SizedBox(height: VSSpacing.md),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(era.subtitle.resolve(lang),
                  style: VSType.subtitleItalic),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small gilt "peak" badge shown above the kicker on a flagship era's Home
/// hero — the visual crown that sets a rare high point apart from the rest.
class _FlagshipBadge extends StatelessWidget {
  const _FlagshipBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 12, 5),
      decoration: BoxDecoration(
        color: VSColors.goldWash,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: VSColors.goldBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.star_rounded, size: 13, color: VSColors.goldBright),
          const SizedBox(width: 6),
          Text('ĐỈNH CAO', style: VSType.kicker),
        ],
      ),
    );
  }
}
