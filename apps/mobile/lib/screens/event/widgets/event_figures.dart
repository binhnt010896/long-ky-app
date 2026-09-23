import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../theme/content_assets.dart';
import '../../../widgets/figure_bust.dart';

/// The figures of an era/event — a horizontal strip of bust portraits, each
/// cropped from the character's reference sheet, with name + epithet. Tapping a
/// tile opens that character's detail page.
class EventFigures extends StatelessWidget {
  const EventFigures({
    required this.figures,
    required this.slug,
    required this.lang,
    super.key,
  });

  final List<Character> figures;

  /// Era slug, for routing to `/era/:slug/figure/:figureId`.
  final String slug;
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    if (figures.isEmpty) return const SizedBox.shrink();
    final label = lang == Lang.vi ? 'NHÂN VẬT' : 'FIGURES';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
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
        ),
        const SizedBox(height: VSSpacing.md),
        SizedBox(
          height: 172,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: figures.length,
            separatorBuilder: (_, __) => const SizedBox(width: VSSpacing.md),
            itemBuilder: (context, i) => _FigureTile(
              character: figures[i],
              lang: lang,
              onTap: () =>
                  context.push('/era/$slug/figure/${figures[i].id}'),
            ),
          ),
        ),
      ],
    );
  }
}

class _FigureTile extends StatelessWidget {
  const _FigureTile({
    required this.character,
    required this.lang,
    required this.onTap,
  });

  final Character character;
  final Lang lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // A dedicated square avatar is rendered whole; a legacy sheet is cropped to
    // its bust (top-right quadrant).
    final avatar = character.avatar;
    final avatarPath = avatar?.flagship ?? avatar?.reduced;
    final sheetPath = character.portrait?.flagship ?? character.portrait?.reduced;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 116,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // The portrait fills the tile edge-to-edge — rounded corners only,
            // no frame/border around the image (the user rejects any framing).
            ClipRRect(
              borderRadius: VSRadii.cardAll,
              child: SizedBox(
                height: 124,
                width: double.infinity,
                child: avatarPath != null
                    ? Image(
                        image: contentImageProvider(avatarPath),
                        fit: BoxFit.cover,
                        frameBuilder: fadeInImageFrame,
                        errorBuilder: (_, __, ___) =>
                            const ColoredBox(color: VSColors.lacquerRaised),
                      )
                    : sheetPath == null
                        ? const ColoredBox(color: VSColors.lacquerRaised)
                        : FigureBust(path: sheetPath),
              ),
            ),
            const SizedBox(height: VSSpacing.sm),
            Text(
              character.name.resolve(lang),
              style: VSType.cardTitle.copyWith(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (character.epithet != null) ...<Widget>[
              const SizedBox(height: 1),
              Text(
                character.epithet!.resolve(lang),
                style: VSType.caption.copyWith(color: VSColors.gold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
