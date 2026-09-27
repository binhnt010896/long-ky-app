import 'dart:async';

import 'package:core_domain/core_domain.dart';
import 'package:experience/experience.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../state/media_prefetch.dart';
import '../../state/providers.dart';
import '../../telemetry/telemetry.dart';
import '../../theme/content_assets.dart';
import '../../widgets/circle_icon_button.dart';
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
  Timer? _eraViewDebounce;

  /// True while a finger is dragging the period rail — suppresses the
  /// per-page prefetch (each crossed period would otherwise queue its media)
  /// in favor of one prefetch when the drag settles. See `_PeriodRail`.
  bool _scrubbing = false;

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
    _eraViewDebounce?.cancel();
    super.dispose();
  }

  /// "Which era do people linger on from Home" — debounced so a fast swipe
  /// through several eras only counts the one the reader stopped on.
  void _onEraSettled(Era era, String periodId) {
    _eraViewDebounce?.cancel();
    _eraViewDebounce = Timer(const Duration(seconds: 1), () {
      ref.read(telemetryProvider).event('era_card_view', <String, Object>{
        'era_slug': era.slug,
        'period_id': periodId,
      });
    });
  }

  void _openEra(Era era) => context.push('/era/${era.slug}');

  void _openNextPeriod() {
    _dynastyController.animateToPage(
      _dynastyIndex + 1,
      duration: VSMotion.control,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dynastiesAsync = ref.watch(dynastiesProvider);
    final lang = ref.watch(langProvider);

    return Scaffold(
      backgroundColor: VSColors.lacquer,
      body: dynastiesAsync.when(
        loading: () => const _LacquerBackdrop(child: _CenterSpinner()),
        error: (e, _) => _LacquerBackdrop(child: _ErrorView(message: '$e')),
        data: (dynasties) {
          if (dynasties.isEmpty) {
            return _LacquerBackdrop(
                child: _ErrorView(
                    message: lang == Lang.en
                        ? 'No dynasties'
                        : 'Không có triều đại nào'));
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
                  // While scrubbing, prefetch happens once on release instead
                  // (_PeriodRail's onScrubEnd below) — not for every period
                  // the finger passes over.
                  if (!_scrubbing) {
                    MediaPrefetcher.instance
                        .queue(prefetchWindow(dynasties, i));
                  }
                },
                itemBuilder: (context, i) {
                  final dynasty = dynasties[i];
                  final periodId = dynasty.period.id;
                  return _DynastyPage(
                    dynasty: dynasty,
                    pointer: _pointer,
                    lang: lang,
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
                    onEraSettled: (era) => _onEraSettled(era, periodId),
                    // The explore affordance is a shortcut past the last period.
                    onExploreNext:
                        i < dynasties.length - 1 ? _openNextPeriod : null,
                  );
                },
              ),
              SafeArea(
                child: _DynastyChrome(period: active, lang: lang),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: _PeriodRail(
                  dynasties: dynasties,
                  activeIndex: _dynastyIndex,
                  lang: lang,
                  onSelect: (i) => _dynastyController.jumpToPage(i),
                  onScrubStart: () => setState(() => _scrubbing = true),
                  onScrubEnd: () {
                    setState(() => _scrubbing = false);
                    MediaPrefetcher.instance
                        .queue(prefetchWindow(dynasties, _dynastyIndex));
                  },
                ),
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
    required this.lang,
    required this.onOpenEra,
    required this.initialEraIndex,
    required this.onEraChanged,
    required this.onEraSettled,
    required this.onExploreNext,
  });

  final Dynasty dynasty;
  final ParallaxController pointer;
  final Lang lang;
  final void Function(Era era) onOpenEra;

  /// Era (horizontal) page to open on, restored from the hub's remembered
  /// position — this page's state is rebuilt whenever it scrolls back into view.
  final int initialEraIndex;
  final ValueChanged<int> onEraChanged;

  /// Called (debounced by the parent) whenever the horizontal pager settles
  /// on an era — drives the `era_card_view` telemetry event.
  final ValueChanged<Era> onEraSettled;

  /// Animates Home to the next period. Null on the last period, which hides
  /// the explore affordance entirely.
  final VoidCallback? onExploreNext;

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
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        PageView.builder(
          controller: _eraController,
          itemCount: eras.length,
          onPageChanged: (i) {
            setState(() => _eraIndex = i);
            widget.onEraChanged(i);
            widget.onEraSettled(widget.dynasty.eras[i]);
          },
          itemBuilder: (context, i) {
            final era = eras[i];
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onOpenEra(era),
              child: EraSceneView(
                era: era,
                pointer: widget.pointer,
                lang: widget.lang,
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
                if (widget.onExploreNext != null)
                  _ExploreAffordance(
                    lang: widget.lang,
                    onTap: widget.onExploreNext!,
                  ),
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
/// right.
class _DynastyChrome extends StatelessWidget {
  const _DynastyChrome({required this.period, required this.lang});

  final Period period;
  final Lang lang;

  @override
  Widget build(BuildContext context) {
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
                      period.title.resolve(lang),
                      style: VSType.title.copyWith(fontSize: 17),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      period.yearRange.display.resolve(lang),
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
                lang: lang,
                onTap: () => context.push('/sanh'),
              ),
            ],
          ),
        ],
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
  const _SideDots({
    required this.count,
    required this.active,
    this.swollen = false,
  });
  final int count;
  final int active;

  /// True while the rail is being scrubbed — dots read slightly larger so the
  /// touch strip feels "live" without adding new always-on chrome at rest.
  final bool swollen;

  @override
  Widget build(BuildContext context) {
    final scale = swollen ? 1.3 : 1.0;
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < count; i++) ...<Widget>[
            if (i == active)
              AnimatedContainer(
                // Keyed distinctly from the inactive dot below so switching
                // which index is active mounts a fresh element instead of
                // animating a BoxDecoration between "circle" and
                // "borderRadius" shapes, which Flutter can't tween (asserts).
                key: ValueKey<String>('pill-$i'),
                duration: VSMotion.control,
                width: 6 * scale,
                height: 22 * scale,
                decoration: const BoxDecoration(
                  gradient: VSColors.goldSheen,
                  borderRadius: BorderRadius.all(Radius.circular(3)),
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: VSColors.goldGlow, blurRadius: 10),
                  ],
                ),
              )
            else
              AnimatedContainer(
                key: ValueKey<String>('dot-$i'),
                duration: VSMotion.control,
                width: 6 * scale,
                height: 6 * scale,
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

/// The right-edge period rail. At rest it's [_SideDots]; an invisible touch
/// strip over it turns a vertical drag into a live scrub across periods
/// (iPhone Contacts-style) — Home follows immediately, a bubble names the
/// period under the finger, and each new period gets a light haptic tick.
/// Tapping (a drag that starts and ends without moving) jumps straight to
/// the tapped period.
class _PeriodRail extends StatefulWidget {
  const _PeriodRail({
    required this.dynasties,
    required this.activeIndex,
    required this.lang,
    required this.onSelect,
    required this.onScrubStart,
    required this.onScrubEnd,
  });

  final List<Dynasty> dynasties;
  final int activeIndex;
  final Lang lang;

  /// The target period index — called on every index the drag crosses (so
  /// Home follows live) and once on a tap.
  final ValueChanged<int> onSelect;
  final VoidCallback onScrubStart;
  final VoidCallback onScrubEnd;

  @override
  State<_PeriodRail> createState() => _PeriodRailState();
}

class _PeriodRailState extends State<_PeriodRail> {
  bool _dragging = false;
  int? _dragIndex;
  int? _lastHapticIndex;

  // A touch target wider than the visible dots (Material's minimum, and
  // forgiving for a thumb), inset from the true screen edge so it doesn't
  // compete with Android's edge-swipe back gesture.
  static const double _touchWidth = 44;
  static const double _railInset = 6;
  // Extra reach above/below the dots themselves, so a finger landing just
  // past the first/last dot still starts the drag.
  static const double _verticalPad = 20;
  static const double _activeDotHeight = 22;
  static const double _dotHeight = 6;
  static const double _dotSpacing = 9;

  /// The dots' own natural height ([_SideDots]'s `Column`, unswollen) — the
  /// touch strip is sized to this plus [_verticalPad], not the full screen,
  /// so it never reaches up into the top chrome (timeline / Sảnh seal).
  double get _dotsHeight {
    final n = widget.dynasties.length;
    if (n == 0) return 0;
    return _activeDotHeight + (n - 1) * (_dotHeight + _dotSpacing);
  }

  double get _railHeight => _dotsHeight + 2 * _verticalPad;

  int _indexForDy(double dy) {
    final count = widget.dynasties.length;
    if (count <= 1) return 0;
    final usable = _dotsHeight.clamp(1.0, double.infinity);
    final t = ((dy - _verticalPad) / usable).clamp(0.0, 1.0);
    return (t * (count - 1)).round();
  }

  void _updateIndex(int index) {
    final clamped = index.clamp(0, widget.dynasties.length - 1);
    if (clamped != _dragIndex) setState(() => _dragIndex = clamped);
    if (clamped != _lastHapticIndex) {
      _lastHapticIndex = clamped;
      HapticFeedback.selectionClick();
      widget.onSelect(clamped);
    }
  }

  void _handleStart(DragStartDetails d) {
    widget.onScrubStart();
    setState(() => _dragging = true);
    _lastHapticIndex = null;
    _updateIndex(_indexForDy(d.localPosition.dy));
  }

  void _handleEnd() {
    setState(() {
      _dragging = false;
      _dragIndex = null;
    });
    widget.onScrubEnd();
  }

  @override
  Widget build(BuildContext context) {
    final activeIndex =
        _dragging ? (_dragIndex ?? widget.activeIndex) : widget.activeIndex;
    final active = widget.dynasties[activeIndex].period;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.centerRight,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(right: _railInset),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: _handleStart,
            onVerticalDragUpdate: (d) =>
                _updateIndex(_indexForDy(d.localPosition.dy)),
            onVerticalDragEnd: (_) => _handleEnd(),
            onVerticalDragCancel: _handleEnd,
            child: SizedBox(
              width: _touchWidth,
              height: _railHeight,
              child: Semantics(
                slider: true,
                label: '${active.title.resolve(widget.lang)} '
                    '(${activeIndex + 1}/${widget.dynasties.length})',
                onIncrease: () => widget.onSelect(
                    (activeIndex + 1).clamp(0, widget.dynasties.length - 1)),
                onDecrease: () => widget.onSelect(
                    (activeIndex - 1).clamp(0, widget.dynasties.length - 1)),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _SideDots(
                    count: widget.dynasties.length,
                    active: activeIndex,
                    swollen: _dragging,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_dragging)
          Positioned(
            right: _touchWidth + _railInset + 8,
            top: (_verticalPad +
                    _dotsHeight *
                        (widget.dynasties.length <= 1
                            ? 0.5
                            : activeIndex / (widget.dynasties.length - 1)))
                .clamp(0.0, _railHeight) -
                28,
            child: _PeriodBubble(period: active, lang: widget.lang),
          ),
      ],
    );
  }
}

/// Floats beside the finger while scrubbing the period rail, naming the
/// period under it — the iPhone-Contacts-style callout.
class _PeriodBubble extends StatelessWidget {
  const _PeriodBubble({required this.period, required this.lang});
  final Period period;
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    final accent = VSColors.fromHex(period.accent);
    return IgnorePointer(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: VSColors.lacquerRaised.withValues(alpha: 0.96),
          borderRadius: VSRadii.cardAll,
          border: Border.all(color: VSColors.goldBorder),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x66000000), blurRadius: 16),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    period.title.resolve(lang),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VSType.cardTitle.copyWith(fontSize: 13),
                  ),
                  Text(
                    period.yearRange.display.resolve(lang),
                    style: VSType.caption.copyWith(
                        color: VSColors.gold, fontSize: 10.5),
                  ),
                ],
              ),
            ),
          ],
        ),
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

/// The bottom-of-page "next period" affordance. Absent on the last period
/// (see `onExploreNext` on [_DynastyPage]) — there is nothing further to go to.
class _ExploreAffordance extends StatelessWidget {
  const _ExploreAffordance({required this.lang, required this.onTap});
  final Lang lang;
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
            lang == Lang.en ? 'EXPLORE' : 'KHÁM PHÁ',
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
