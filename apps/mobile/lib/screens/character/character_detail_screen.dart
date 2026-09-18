import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../state/providers.dart';
import '../../theme/content_assets.dart';
import '../../theme/era_palette_mapping.dart';
import '../../widgets/circle_icon_button.dart';
import '../../widgets/figure_bust.dart';
import '../../widgets/lang_toggle.dart';
import '../../widgets/tilted_backdrop.dart';

/// Character Detail — a figure's portrait, chronicle-grounded biography, and the
/// events in the era where they appear. Reached by tapping a figure avatar.
class CharacterDetailScreen extends ConsumerWidget {
  const CharacterDetailScreen({
    required this.slug,
    required this.figureId,
    super.key,
  });

  final String slug;
  final String figureId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eraAsync = ref.watch(eraProvider(slug));
    final lang = ref.watch(langProvider);

    return Scaffold(
      backgroundColor: VSColors.lacquer,
      body: eraAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: VSColors.gold),
        ),
        error: (e, _) => Center(child: Text('$e', style: VSType.bodySmall)),
        data: (era) {
          final figure = era.figureById(figureId);
          if (figure == null) {
            return Center(
              child: Text(
                lang == Lang.vi ? 'Không tìm thấy nhân vật' : 'Figure not found',
                style: VSType.bodySmall,
              ),
            );
          }
          final appearances = era.eventsWithFigure(figureId);
          return TiltedBackdrop(
            era: era,
            palette: paletteForEra(era),
            scrim: 0.4,
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: <Widget>[
                  ListView(
                    padding: EdgeInsets.zero,
                    children: <Widget>[
                      _FigureHero(figure: figure, lang: lang),
                      _FigureSheet(
                        era: era,
                        figure: figure,
                        appearances: appearances,
                        lang: lang,
                      ),
                    ],
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: VSSpacing.xl)
                            .add(const EdgeInsets.only(top: VSSpacing.sm)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        CircleIconButton(
                          icon: Icons.arrow_back,
                          onTap: () => context.pop(),
                        ),
                        const LangToggle(),
                      ],
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

class _FigureHero extends StatelessWidget {
  const _FigureHero({required this.figure, required this.lang});

  final Character figure;
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // A dedicated full-body image is a 2:3 portrait, rendered whole. A legacy
    // sheet instead exposes its full-body figure in the left panel (aspect
    // ~0.52). Either way the frame keeps the art's aspect so nothing stretches.
    final fullBody = figure.fullBody;
    final fullBodyPath = fullBody?.flagship ?? fullBody?.reduced;
    final sheetPath = figure.portrait?.flagship ?? figure.portrait?.reduced;
    final aspect = fullBodyPath != null ? 2 / 3 : FigureBust.fullBody.width;
    final frameWidth = (size.width * 0.58).clamp(180.0, 260.0);
    final frameHeight = frameWidth / aspect;
    return Padding(
      // Top pad clears the pinned back/toggle chrome.
      padding: const EdgeInsets.fromLTRB(
          VSSpacing.xl, 64, VSSpacing.xl, VSSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // The portrait stands on its own — rounded corners and a soft drop
          // shadow for depth, but NO frame/border around the image itself.
          Container(
            width: frameWidth,
            height: frameHeight,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              borderRadius: VSRadii.cardAll,
              boxShadow: <BoxShadow>[
                BoxShadow(
                    color: Color(0x80000000), blurRadius: 40, offset: Offset(0, 16)),
              ],
            ),
            child: fullBodyPath != null
                ? Image.asset(contentAssetKey(fullBodyPath), fit: BoxFit.cover)
                : sheetPath == null
                    ? const ColoredBox(color: VSColors.lacquerRaised)
                    : FigureBust(
                        assetKey: contentAssetKey(sheetPath),
                        srcFraction: FigureBust.fullBody,
                      ),
          ),
          const SizedBox(height: VSSpacing.lg),
          Text(
            figure.name.resolve(lang),
            style: VSType.title.copyWith(
              shadows: const <Shadow>[
                Shadow(
                    color: Color(0x99000000),
                    blurRadius: 22,
                    offset: Offset(0, 2)),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          if (figure.epithet != null) ...<Widget>[
            const SizedBox(height: VSSpacing.sm),
            Text(
              figure.epithet!.resolve(lang).toUpperCase(),
              style: VSType.label.copyWith(
                color: VSColors.goldBright,
                letterSpacing: VSType.track(0.24, 12),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _FigureSheet extends StatelessWidget {
  const _FigureSheet({
    required this.era,
    required this.figure,
    required this.appearances,
    required this.lang,
  });

  final Era era;
  final Character figure;
  final List<HistoryEvent> appearances;
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    const sheet = Color(0xF2060D0C);
    final source = era.primarySource;
    final section = source.section?.resolve(lang);
    return Column(
      children: <Widget>[
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
              if (figure.bio != null)
                Text(
                  figure.bio!.resolve(lang),
                  style: VSType.body.copyWith(color: VSColors.inkBody),
                ),
              if (appearances.isNotEmpty) ...<Widget>[
                const SizedBox(height: VSSpacing.xl),
                _SectionHeader(
                  label: lang == Lang.vi ? 'XUẤT HIỆN TRONG' : 'APPEARS IN',
                ),
                const SizedBox(height: VSSpacing.md),
                for (final e in appearances) ...<Widget>[
                  _AppearanceRow(
                    event: e,
                    lang: lang,
                    onTap: () =>
                        context.push('/era/${era.slug}/event/${e.id}'),
                  ),
                  const SizedBox(height: VSSpacing.sm),
                ],
              ],
              const SizedBox(height: VSSpacing.xl),
              // Provenance line — the era's single chronicle.
              Row(
                children: <Widget>[
                  const Icon(Icons.auto_stories,
                      size: 15, color: VSColors.gold),
                  const SizedBox(width: VSSpacing.sm),
                  Expanded(
                    child: Text(
                      section == null
                          ? source.work
                          : '${source.work} · $section',
                      style: VSType.caption.copyWith(
                        color: VSColors.inkMuted,
                        letterSpacing: VSType.track(0.1, 11),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          label,
          style: VSType.overline.copyWith(
            color: VSColors.goldBright,
            letterSpacing: VSType.track(0.34, 10),
            fontSize: 10,
          ),
        ),
        const SizedBox(width: VSSpacing.sm),
        Expanded(
          child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[VSColors.goldBorder, Color(0x00C9A24B)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AppearanceRow extends StatelessWidget {
  const _AppearanceRow({
    required this.event,
    required this.lang,
    required this.onTap,
  });

  final HistoryEvent event;
  final Lang lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: VSSpacing.md, vertical: VSSpacing.md - 3),
        decoration: BoxDecoration(
          color: VSColors.inkPrimary.withValues(alpha: 0.03),
          borderRadius: VSRadii.cardAll,
          border: Border.all(color: VSColors.inkPrimary.withValues(alpha: 0.08)),
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
                  const SizedBox(height: 3),
                  Text(
                    event.title.resolve(lang),
                    style: VSType.cardTitle.copyWith(fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: VSSpacing.sm),
            const Icon(Icons.arrow_forward, size: 16, color: VSColors.goldBright),
          ],
        ),
      ),
    );
  }
}
