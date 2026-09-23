import 'package:core_domain/core_domain.dart';
import 'package:experience/experience.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../state/media_prefetch.dart';
import '../../state/providers.dart';
import '../../theme/content_assets.dart';
import '../../widgets/circle_icon_button.dart';
import '../../widgets/flag_mark.dart';
import '../../widgets/seal_button.dart';
import 'widgets/era_scene_view.dart';

/// Home — the dynasty hub. Two axes: swipe **vertically** to move between
/// dynasties (periods), and **horizontally** to move between the eras within the
/// current dynasty. Tap an era (or the explore affordance) to enter it.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final PageController _dynastyController;
  final ParallaxController _pointer = ParallaxController();
  TiltParallaxDriver? _tilt;
  late int _dynastyIndex;
  bool _queuedInitialPrefetch = false;

  @override
  void initState() {
    super.initState();
    // Restore the dynasty the user last left off on (survives Home being rebuilt
    // by a stack-replacing back navigation). Clamped in build against the count.
    _dynastyIndex = ref.read(hubDynastyIndexProvider).clamp(0, 1 << 30);
    _dynastyController = PageController(initialPage: _dynastyIndex);
    // Tilt is a flagship capability; start it only when the tier grants it.
    if (ref.read(tierProvider).capabilities.tilt) {
      _tilt = TiltParallaxDriver(_pointer)..start();
    }
  }

  @override
  void dispose() {
    _tilt?.dispose();
    _pointer.dispose();
    _dynastyController.dispose();
    super.dispose();
  }

  void _openEra(Era era) => context.push('/era/${era.slug}');

  @override
  Widget build(BuildContext context) {
    final dynastiesAsync = ref.watch(dynastiesProvider);

    return Scaffold(
      backgroundColor: VSColors.lacquer,
      body: dynastiesAsync.when(
        loading: () => const _LacquerBackdrop(child: _CenterSpinner()),
        error: (e, _) => _LacquerBackdrop(child: _ErrorView(message: '$e')),
        data: (dynasties) {
          if (dynasties.isEmpty) {
            return const _LacquerBackdrop(
                child: _ErrorView(message: 'No dynasties'));
          }
          final active =
              dynasties[_dynastyIndex.clamp(0, dynasties.length - 1)].period;
          if (!_queuedInitialPrefetch) {
            _queuedInitialPrefetch = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              MediaPrefetcher.instance
                  .queue(prefetchWindow(dynasties, _dynastyIndex));
            });
          }
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              PageView.builder(
                key: const ValueKey<String>('dynasty-pager'),
                controller: _dynastyController,
                scrollDirection: Axis.vertical,
                itemCount: dynasties.length,
                onPageChanged: (i) {
                  setState(() => _dynastyIndex = i);
                  ref.read(hubDynastyIndexProvider.notifier).state = i;
                  MediaPrefetcher.instance.queue(prefetchWindow(dynasties, i));
                },
                itemBuilder: (context, i) {
                  final dynasty = dynasties[i];
                  final periodId = dynasty.period.id;
                  return _DynastyPage(
                    dynasty: dynasty,
                    pointer: _pointer,
                    onOpenEra: _openEra,
                    // Restore (and remember) the era this dynasty was left on, so
                    // scrolling away to another dynasty and back keeps the column.
                    initialEraIndex:
                        ref.read(hubEraIndexProvider)[periodId] ?? 0,
                    onEraChanged: (eraIndex) {
                      final next =
                          Map<String, int>.from(ref.read(hubEraIndexProvider));
                      next[periodId] = eraIndex;
                      ref.read(hubEraIndexProvider.notifier).state = next;
                    },
                  );
                },
              ),
              SafeArea(
                child: _DynastyChrome(period: active),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: _SideDots(count: dynasties.length, active: _dynastyIndex),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One dynasty page: a horizontal stack of that dynasty's eras, with an
/// era-position strip and an explore affordance for the centred era.
class _DynastyPage extends StatefulWidget {
  const _DynastyPage({
    required this.dynasty,
    required this.pointer,
    required this.onOpenEra,
    required this.initialEraIndex,
    required this.onEraChanged,
  });

  final Dynasty dynasty;
  final ParallaxController pointer;
  final void Function(Era era) onOpenEra;

  /// Era (horizontal) page to open on, restored from the hub's remembered
  /// position — this page's state is rebuilt whenever it scrolls back into view.
  final int initialEraIndex;
  final ValueChanged<int> onEraChanged;

  @override
  State<_DynastyPage> createState() => _DynastyPageState();
}

class _DynastyPageState extends State<_DynastyPage> {
  late final PageController _eraController;
  late int _eraIndex;

  @override
  void initState() {
    super.initState();
    _eraIndex = widget.initialEraIndex
        .clamp(0, (widget.dynasty.eras.length - 1).clamp(0, 1 << 30));
    _eraController = PageController(initialPage: _eraIndex);
  }

  @override
  void dispose() {
    _eraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eras = widget.dynasty.eras;
    final active = eras[_eraIndex.clamp(0, eras.length - 1)];
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        PageView.builder(
          controller: _eraController,
          itemCount: eras.length,
          onPageChanged: (i) {
            setState(() => _eraIndex = i);
            widget.onEraChanged(i);
          },
          itemBuilder: (context, i) {
            final era = eras[i];
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onOpenEra(era),
              child: EraSceneView(
                era: era,
                pointer: widget.pointer,
                lang: Lang.vi,
              ),
            );
          },
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (eras.length > 1) ...<Widget>[
                  _EraStrip(count: eras.length, active: _eraIndex),
                  const SizedBox(height: VSSpacing.lg),
                ],
                _ExploreAffordance(onTap: () => widget.onOpenEra(active)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LacquerBackdrop extends StatelessWidget {
  const _LacquerBackdrop({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(color: VSColors.lacquer),
        child: Center(child: child),
      );
}

class _CenterSpinner extends StatelessWidget {
  const _CenterSpinner();
  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(strokeWidth: 2, color: VSColors.gold),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(VSSpacing.xl),
        child: Text(message, style: VSType.bodySmall, textAlign: TextAlign.center),
      );
}

/// Top chrome for the dynasty hub: the current dynasty's crest, name and span on
/// the left; the global-timeline entry and the Long Ký seal (the Sảnh) on the
/// right; and the daily Chào cờ prompt beneath.
class _DynastyChrome extends ConsumerWidget {
  const _DynastyChrome({required this.period});

  final Period period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = VSColors.fromHex(period.accent);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: VSSpacing.screenEdge)
          .add(const EdgeInsets.only(top: 12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _DynastyCrest(period: period, accent: accent),
              const SizedBox(width: VSSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      period.title.resolve(Lang.vi),
                      style: VSType.title.copyWith(fontSize: 17),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      period.yearRange.display.resolve(Lang.vi),
                      style: VSType.caption.copyWith(
                        color: VSColors.gold,
                        fontSize: 10.5,
                        letterSpacing: VSType.track(0.14, 11),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: VSSpacing.sm),
              CircleIconButton(
                icon: Icons.timeline_rounded,
                size: 34,
                onTap: () => context.push('/timeline'),
              ),
              const SizedBox(width: VSSpacing.sm),
              SealButton(
                key: const ValueKey<String>('home-sanh-seal'),
                onTap: () => context.push('/sanh'),
              ),
            ],
          ),
          const SizedBox(height: VSSpacing.sm),
          _ChaoCoPill(occasion: nationalDayOn(ref.watch(todayProvider))),
        ],
      ),
    );
  }
}

/// The daily Chào cờ prompt: always shown; on national days it names the day.
class _ChaoCoPill extends StatelessWidget {
  const _ChaoCoPill({required this.occasion});

  final String? occasion;

  @override
  Widget build(BuildContext context) {
    final lead = occasion == null ? 'CHÀO CỜ HÔM NAY' : '$occasion  ·  CHÀO CỜ';
    final style = VSType.caption.copyWith(
      fontSize: 10.5,
      letterSpacing: VSType.track(0.16, 10.5),
      color: VSColors.inkSecondary,
    );
    return GestureDetector(
      key: const ValueKey<String>('home-chao-co'),
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/chao-co'),
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: VSSpacing.sm),
        decoration: BoxDecoration(
          color: VSColors.lacquer.withValues(alpha: 0.45),
          borderRadius: VSRadii.pillAll,
          border: Border.all(color: VSColors.goldBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const FlagMark(width: 14),
            const SizedBox(width: VSSpacing.xs),
            Flexible(
              child: Text(
                occasion == null ? lead : lead.toUpperCase(),
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: VSSpacing.xs),
            Text('›',
                style: style.copyWith(
                    color: VSColors.goldBright, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

/// The dynasty's cover art as a small rounded crest, falling back to an
/// accent-tinted seal when art is absent.
class _DynastyCrest extends StatelessWidget {
  const _DynastyCrest({required this.period, required this.accent});

  final Period period;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final path = period.cover?.reduced ?? period.cover?.flagship;
    const double size = 44;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VSColors.goldBorder),
        color: accent.withValues(alpha: 0.25),
      ),
      clipBehavior: Clip.antiAlias,
      child: path == null
          ? Icon(Icons.brightness_1, size: 12, color: accent)
          : Image(
              image: contentImageProvider(path,
                  decodeWidth: decodeWidthFor(context, size)),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              frameBuilder: fadeInImageFrame,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.brightness_1, size: 12, color: accent),
            ),
    );
  }
}

/// Vertical rail on the right: which dynasty you're on. A gold pill for the
/// active dynasty, fading dots for the rest.
class _SideDots extends StatelessWidget {
  const _SideDots({required this.count, required this.active});
  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < count; i++) ...<Widget>[
            if (i == active)
              Container(
                width: 6,
                height: 22,
                decoration: const BoxDecoration(
                  gradient: VSColors.goldSheen,
                  borderRadius: BorderRadius.all(Radius.circular(3)),
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: VSColors.goldGlow, blurRadius: 10),
                  ],
                ),
              )
            else
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: VSColors.inkPrimary
                      .withValues(alpha: 0.35 - (i * 0.03).clamp(0, 0.25)),
                ),
              ),
            if (i != count - 1) const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }
}

/// Horizontal era-position strip within a dynasty: a widened gold dash for the
/// active era, small dots for the rest.
class _EraStrip extends StatelessWidget {
  const _EraStrip({required this.count, required this.active});
  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < count; i++) ...<Widget>[
          if (i == active)
            Container(
              width: 20,
              height: 5,
              decoration: const BoxDecoration(
                gradient: VSColors.goldSheen,
                borderRadius: BorderRadius.all(Radius.circular(3)),
              ),
            )
          else
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: VSColors.inkPrimary.withValues(alpha: 0.35),
              ),
            ),
          if (i != count - 1) const SizedBox(width: 7),
        ],
      ],
    );
  }
}

class _ExploreAffordance extends StatelessWidget {
  const _ExploreAffordance({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: VSColors.gold.withValues(alpha: 0.55)),
            ),
            child: const Center(
              child: Icon(Icons.keyboard_arrow_up,
                  size: 20, color: VSColors.goldBright),
            ),
          ),
          const SizedBox(height: VSSpacing.sm),
          Text(
            'KHÁM PHÁ',
            style: VSType.caption.copyWith(
              letterSpacing: VSType.track(0.24, 11),
              fontSize: 11,
              color: VSColors.inkPrimary.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}
