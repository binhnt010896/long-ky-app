import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../state/providers.dart';
import '../../theme/content_assets.dart';
import '../../widgets/circle_icon_button.dart';
import '../../widgets/lang_toggle.dart';
import '../../widgets/portrait_placeholder.dart';
import '../streets/street_reverse_chip.dart';
import 'character_detail_screen.dart'
    show FigureAppearanceRow, FigureSectionHeader;

/// A standalone person — one no era's roster lists (Cycle R). The same name,
/// epithet and biography as an in-era figure, but no era scene to borrow: a
/// neutral lacquer ground, the person's life dates as the kicker, and the
/// standalone events they appear in.
///
/// `/nhan-vat/:id` only builds this for a person on no roster — one who is on a
/// roster is redirected to `/era/:slug/figure/:id` before it gets here.
class StandaloneCharacterScreen extends ConsumerWidget {
  const StandaloneCharacterScreen({required this.figureId, super.key});

  final String figureId;

  static const String viLabel = 'NHÂN VẬT';
  static const String enLabel = 'FIGURE';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    final people = ref.watch(peopleProvider);
    return Scaffold(
      backgroundColor: VSColors.lacquer,
      body: people.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: VSColors.gold),
        ),
        error: (e, _) => Center(child: Text('$e', style: VSType.bodySmall)),
        data: (registry) {
          final figure = registry[figureId];
          if (figure == null) return _NotFound(lang: lang);
          final appearances = <HistoryEvent>[
            for (final e in ref.watch(standaloneEventsProvider).valueOrNull ??
                const <HistoryEvent>[])
              if (e.figureIds.contains(figureId)) e,
          ];
          return Stack(
            children: <Widget>[
              ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  _Hero(figure: figure, lang: lang),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        VSSpacing.xl, VSSpacing.lg, VSSpacing.xl, 40),
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
                          FigureSectionHeader(
                            label: lang == Lang.vi
                                ? 'XUẤT HIỆN TRONG'
                                : 'APPEARS IN',
                          ),
                          const SizedBox(height: VSSpacing.md),
                          for (final e in appearances) ...<Widget>[
                            FigureAppearanceRow(
                              event: e,
                              lang: lang,
                              onTap: () => context.push('/su-kien/${e.id}'),
                            ),
                            const SizedBox(height: VSSpacing.sm),
                          ],
                        ],
                        StreetReverseChip(
                            type: StreetTargetType.person, id: figure.id),
                      ],
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
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: VSSpacing.md),
              child: Text(
                lang == Lang.vi
                    ? StandaloneCharacterScreen.viLabel
                    : StandaloneCharacterScreen.enLabel,
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

/// The portrait (when there is one), then name, epithet and life dates. A
/// person whose portrait is held has no portrait block at all — the page leads
/// with the name instead of a blank tile.
class _Hero extends StatelessWidget {
  const _Hero({required this.figure, required this.lang});

  final Character figure;
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final fullBody = figure.fullBody;
    final path = fullBody?.flagship ?? fullBody?.reduced;
    final frameWidth = (size.width * 0.58).clamp(180.0, 260.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          VSSpacing.xl, 64, VSSpacing.xl, VSSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (path != null)
            Container(
              key: const Key('standalone-portrait'),
              width: frameWidth,
              height: frameWidth * 1.5,
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                borderRadius: VSRadii.cardAll,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                      color: Color(0x80000000),
                      blurRadius: 40,
                      offset: Offset(0, 16)),
                ],
              ),
              child: Image(
                image: contentImageProvider(path),
                fit: BoxFit.cover,
                frameBuilder: fadeInImageFrame,
                errorBuilder: (_, __, ___) => const PortraitPlaceholder(),
              ),
            )
          else
            const SizedBox(height: VSSpacing.lg),
          const SizedBox(height: VSSpacing.lg),
          Text(
            figure.name.resolve(lang),
            style: VSType.title,
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
          if (figure.lifespan != null) ...<Widget>[
            const SizedBox(height: VSSpacing.sm),
            Text(
              figure.lifespan!.resolve(lang),
              style: VSType.caption.copyWith(
                color: VSColors.gold,
                letterSpacing: VSType.track(0.14, 11),
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
                lang == Lang.vi ? 'Không tìm thấy nhân vật' : 'Figure not found',
                style: VSType.body.copyWith(color: VSColors.inkSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
