import 'dart:async';

import 'package:core_content/core_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../state/content_sync.dart';
import '../../state/media_prefetch.dart';
import '../../state/providers.dart';
import '../../telemetry/telemetry.dart';
import '../../theme/content_assets.dart';
import '../streets/street_basemap.dart';
import '../streets/street_data.dart';
import '../streets/street_map_warmer.dart';
import '../streets/street_perf.dart';

/// Wraps the app and shows the **Long Ký** brand splash over it on launch, then
/// fades away to reveal [child].
///
/// While the seal rises in, it does two things in sequence:
///
/// 1. Checks for a newer content pack, waiting at most 2s — if one arrives in
///    time it's adopted before Home shows; otherwise the check keeps running
///    in the background and the pack is adopted live the moment it lands.
/// 2. Warms the first Home page's media (the active dynasty's period cover
///    and its first era's scene layers) into the on-device cache, so Home
///    shows its art immediately instead of popping in over a few seconds.
///
/// The splash never blocks longer than [_hardCap] in total — a slow or
/// offline connection still opens the app, just to fallbacks.
///
/// It lives only in the real app entry (`VietSuApp`) via `MaterialApp.router`'s
/// `builder`, so the widget-test harness — which mounts screens through its own
/// router — never sees it and never has to wait out its timers or touch the
/// network.
class SplashGate extends ConsumerStatefulWidget {
  const SplashGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends ConsumerState<SplashGate>
    with WidgetsBindingObserver {
  static const _minShow = Duration(milliseconds: 1950);
  static const _hardCap = Duration(seconds: 8);
  static const _fadeOut = Duration(milliseconds: 650);

  bool _present = true; // overlay still in the tree
  bool _contentIn = false; // logo + wordmark have risen in
  bool _fadingOut = false; // whole overlay fading away

  bool _minElapsed = false;
  bool _warmDone = false;
  bool _hardCapped = false;
  bool _showBar = false; // only turns on if still up past _minShow
  double _warmProgress = 0;

  final List<Timer> _timers = <Timer>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timers.add(Timer(
        const Duration(milliseconds: 90), () => setState(() => _contentIn = true)));
    _timers.add(Timer(_minShow, () {
      if (!mounted) return;
      setState(() {
        _minElapsed = true;
        if (!_warmDone) _showBar = true;
      });
      _maybeFadeOut();
    }));
    _timers.add(Timer(_hardCap, () {
      if (!mounted) return;
      setState(() => _hardCapped = true);
      _maybeFadeOut();
    }));
    unawaited(_run());
  }

  // Android keeps the app alive for days, so a launch-only check would leave
  // published text and images unseen until a cold start. Coming back to the
  // foreground checks again, at most every [kForegroundCheckEvery].
  DateTime _lastCheck = DateTime.now();
  bool _checking = true; // the launch check is running

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!shouldCheckOnResume(
        now: DateTime.now(), last: _lastCheck, busy: _checking)) {
      return;
    }
    unawaited(_checkLive());
  }

  Future<void> _checkLive() async {
    _checking = true;
    _lastCheck = DateTime.now();
    try {
      final pack = await ContentSync.checkForUpdate(
          ref.read(activeContentVersionProvider));
      if (pack != null && mounted &&
          pack.version > ref.read(activeContentVersionProvider)) {
        _activatePack(pack, live: true);
      }
    } finally {
      _checking = false;
    }
  }

  Future<void> _run() async {
    final activeVersion = ref.read(activeContentVersionProvider);
    // checkForUpdate never throws. A pack that arrives within the splash's
    // window is adopted before Home shows; one that takes longer (the usual
    // case on a phone: latest.json plus a ~2 MB pack) is adopted live when
    // it lands, instead of waiting for the next launch.
    final launchCheck = ContentSync.checkForUpdate(activeVersion);
    unawaited(launchCheck.whenComplete(() {
      _checking = false;
      _lastCheck = DateTime.now();
    }));
    await adoptPackWhenReady<ContentPack>(
      launchCheck,
      window: const Duration(seconds: 2),
      adopt: (pack, {required live}) {
        if (!mounted) return;
        // A later launch's check can't race this one, but stay monotonic.
        if (pack.version <= ref.read(activeContentVersionProvider)) return;
        _activatePack(pack, live: live);
      },
    );
    // After the pack, so it warms the pack's street mapping. Not awaited: the
    // map is a side trip, and must never hold the splash.
    unawaited(_warmStreets());
    await _warmUp();
  }

  /// Opens the street map's parts in the background — the street geometry and
  /// the base map archive (its header and directories are a chain of serial
  /// requests that used to run when the map screen opened). Safe to skip or
  /// fail: the street screen loads them itself, just later.
  Future<void> _warmStreets() async {
    if (debugContentImageOverride != null) return; // widget tests: no network
    StreetPerf.instance.mark('splash_streets_start');
    try {
      final results = await Future.wait<Object?>(<Future<Object?>>[
        ref.read(streetMapDataProvider.future).then((v) {
          StreetPerf.instance.mark('splash_data_ready');
          return v;
        }),
        ref.read(streetBasemapProvider.future),
      ]);
      // Then the tiles of the first view, so the map paints from memory.
      final basemap = results[1] as StreetBasemap?;
      final start = (results[0] as StreetMapData?)?.file.start;
      if (basemap != null && start != null) {
        await basemap.prefetch(startViewTiles(start.lat, start.lng, start.zoom));
        StreetPerf.instance.mark('splash_prefetch_done');
        // Then draw the first view out of sight, so its tile images are
        // already on disk when the map opens (see StreetMapWarmer).
        if (mounted) ref.read(streetWarmProvider.notifier).state = true;
      }
    } catch (_) {
      // Never surfaces: this is only a head start.
    }
  }

  /// Adopts a freshly-validated pack: swaps it in as the OTA overlay, applies
  /// its media manifest, and drops every provider's cache so the next read
  /// reflects the new content. Under the splash ([live] false) Home is still
  /// hidden; [live] true means the app is in use — screens on show refresh in
  /// place (Riverpod keeps their old data until the new read lands, so nothing
  /// flashes back to a spinner).
  void _activatePack(ContentPack pack, {required bool live}) {
    final source = ref.read(contentRepositoryProvider).source;
    if (source is OtaContentSource) {
      source.overlay = PackContentSource(pack);
    }
    ContentMedia.applyManifest(pack.media);
    ref.read(contentRepositoryProvider).invalidate();
    ref.invalidate(dynastiesProvider);
    ref.invalidate(erasProvider);
    ref.invalidate(periodsProvider);
    ref.invalidate(eraProvider);
    // The pack may carry a newer street mapping than the bundled one.
    ref.invalidate(streetMappingProvider);
    ref.invalidate(streetMapDataProvider);
    ref.read(activeContentVersionProvider.notifier).state = pack.version;
    ref.read(telemetryProvider).event('content_pack_adopted',
        <String, Object>{'version': pack.version, 'at': live ? 'live' : 'splash'});
  }

  Future<void> _warmUp() async {
    try {
      final dynasties = await ref.read(dynastiesProvider.future);
      if (dynasties.isEmpty) return;
      await MediaPrefetcher.instance.warm(
        firstPageMediaFor(dynasties.first),
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() => _warmProgress = total == 0 ? 1 : done / total);
        },
      );
    } catch (_) {
      // A failed or slow warm-up must never block the app opening — the
      // hard cap (or a completed minimum show) reveals it regardless.
    }
    if (!mounted) return;
    setState(() => _warmDone = true);
    _maybeFadeOut();
  }

  void _maybeFadeOut() {
    if (_fadingOut || !_minElapsed || !(_warmDone || _hardCapped)) return;
    setState(() => _fadingOut = true);
    _timers.add(Timer(_fadeOut, () {
      if (mounted) setState(() => _present = false);
    }));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        widget.child,
        const StreetMapWarmer(),
        if (_present)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: _fadingOut,
              child: AnimatedOpacity(
                opacity: _fadingOut ? 0 : 1,
                duration: const Duration(milliseconds: 620),
                curve: Curves.easeOut,
                // The overlay sits in MaterialApp's `builder`, above the
                // Navigator and so outside any Material: without this, its
                // Text has no DefaultTextStyle and Flutter draws its yellow
                // double-underline "missing Material" debug marker.
                child: Material(
                  type: MaterialType.transparency,
                  child: SplashScreenView(
                    contentIn: _contentIn,
                    showProgress: _showBar,
                    progress: _warmProgress,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The splash's background art: a gold Nguyễn-style dragon among clouds on
/// black lacquer (Cycle Q). Bundled — the splash shows before the network or
/// the media cache are ready.
const String kSplashArt = 'assets/brand/splash-bg.webp';

/// The Long Ký splash: gold dragon-and-cloud art on lacquer, the seal over a
/// soft dark pool so it stays crisp, the wordmark below, and (only once the
/// minimum show time has passed and media is still warming) a thin gold
/// progress bar.
///
/// The art drifts very slowly (a ~3 % zoom over the splash's few seconds),
/// unless the phone asks for reduced motion.
class SplashScreenView extends StatefulWidget {
  const SplashScreenView({
    super.key,
    required this.contentIn,
    required this.showProgress,
    required this.progress,
  });

  final bool contentIn;
  final bool showProgress;
  final double progress;

  @override
  State<SplashScreenView> createState() => _SplashScreenViewState();
}

class _SplashScreenViewState extends State<SplashScreenView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
      vsync: this, duration: const Duration(seconds: 9));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Decode the art before the first frame that needs it.
    precacheImage(const AssetImage(kSplashArt), context);
    if (!_started && !MediaQuery.disableAnimationsOf(context)) {
      _started = true;
      _drift.forward();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: VSColors.lacquerVoid,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // The art: cover-fit and centred, so a taller or wider phone crops
          // the edges, never the middle. Fades in with the seal.
          AnimatedOpacity(
            opacity: widget.contentIn ? 1 : 0,
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOut,
            child: AnimatedBuilder(
              animation: _drift,
              builder: (context, child) => Transform.scale(
                scale: 1 + 0.03 * Curves.easeOut.transform(_drift.value),
                child: child,
              ),
              child: Image.asset(
                kSplashArt,
                key: const Key('splash-art'),
                fit: BoxFit.cover,
                alignment: Alignment.center,
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
              ),
            ),
          ),
          // A soft dark pool behind the seal and wordmark, so they stay crisp
          // on any part of the art.
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.06),
                  radius: 0.78,
                  colors: <Color>[Color(0xD907100F), Color(0x9907100F), Color(0x0007100F)],
                  stops: <double>[0, 0.55, 1],
                ),
              ),
              child: SizedBox.expand(),
            ),
          ),
          Center(child: _SplashContent(widget: widget)),
        ],
      ),
    );
  }
}

class _SplashContent extends StatelessWidget {
  const _SplashContent({required this.widget});

  final SplashScreenView widget;

  @override
  Widget build(BuildContext context) {
    final contentIn = widget.contentIn;
    return AnimatedSlide(
      offset: contentIn ? Offset.zero : const Offset(0, 0.04),
      duration: const Duration(milliseconds: 720),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: contentIn ? 1 : 0,
        duration: const Duration(milliseconds: 720),
        curve: Curves.easeOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // The seal, on a soft gold halo.
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(34),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: VSColors.gold.withValues(alpha: 0.22),
                    blurRadius: 56,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(34),
                child: Image.asset(
                  'assets/brand/long-ky-logo.png',
                  width: 184,
                  height: 184,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
            const SizedBox(height: VSSpacing.xl),
            // Wordmark — Playfair Display Italic, gilded.
            Text(
              'Long Ký',
              key: const Key('splash-wordmark'),
              style: VSType.hero.copyWith(
                fontSize: 44,
                fontStyle: FontStyle.italic,
                color: VSColors.goldBright,
                letterSpacing: 0.5,
                shadows: const <Shadow>[
                  Shadow(color: Color(0x99000000), blurRadius: 18),
                ],
              ),
            ),
            const SizedBox(height: VSSpacing.md),
            Container(width: 40, height: 1, color: VSColors.goldBorder),
            const SizedBox(height: VSSpacing.md),
            Text('NGHÌN NĂM SỬ VIỆT', style: VSType.kicker),
            const SizedBox(height: VSSpacing.lg),
            AnimatedOpacity(
              opacity: widget.showProgress ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                width: 120,
                height: 2,
                decoration: BoxDecoration(
                  color: VSColors.goldBorder,
                  borderRadius: BorderRadius.circular(1),
                ),
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  width: 120 * widget.progress.clamp(0, 1),
                  height: 2,
                  decoration: BoxDecoration(
                    color: VSColors.goldBright,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Waits up to [window] for [check]. A result within the window is adopted
/// with `live: false`; a later one with `live: true` (the caller is not kept
/// waiting for it). A null result — no newer pack, or a failed check — adopts
/// nothing.
Future<void> adoptPackWhenReady<T>(
  Future<T?> check, {
  required Duration window,
  required void Function(T pack, {required bool live}) adopt,
}) async {
  var inWindow = false;
  final early = await check.then<T?>((p) {
    inWindow = true;
    return p;
  }).timeout(window, onTimeout: () => null);
  if (inWindow) {
    if (early != null) adopt(early, live: false);
    return;
  }
  unawaited(check.then((late) {
    if (late != null) adopt(late, live: true);
  }));
}

/// How long after the last check a return to the foreground checks again.
const Duration kForegroundCheckEvery = Duration(minutes: 30);

/// Whether coming back to the foreground should look for a newer pack: not
/// while a check is already running, and not within [every] of the last one.
bool shouldCheckOnResume({
  required DateTime now,
  required DateTime last,
  required bool busy,
  Duration every = kForegroundCheckEvery,
}) =>
    !busy && now.difference(last) >= every;
