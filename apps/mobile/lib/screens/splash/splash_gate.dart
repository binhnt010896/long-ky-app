import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../state/media_prefetch.dart';
import '../../state/providers.dart';

/// Wraps the app and shows the **Long Ký** brand splash over it on launch, then
/// fades away to reveal [child].
///
/// While the seal rises in, it also warms the first Home page's media (the
/// active dynasty's period cover and its first era's scene layers) into the
/// on-device cache, so Home shows its art immediately instead of popping in
/// over a few seconds. The splash never blocks longer than [_hardCap] on this
/// — a slow or offline connection still opens the app, just to fallbacks.
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

class _SplashGateState extends ConsumerState<SplashGate> {
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
    unawaited(_warmUp());
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
                  child: _SplashScreen(
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

/// The Long Ký splash: the seal on a deep lacquer ground, the wordmark below,
/// and (only once the minimum show time has passed and media is still
/// warming) a thin gold progress bar.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen({
    required this.contentIn,
    required this.showProgress,
    required this.progress,
  });

  final bool contentIn;
  final bool showProgress;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.18),
          radius: 1.15,
          colors: <Color>[Color(0xFF1C0C0A), VSColors.lacquerVoid],
        ),
      ),
      child: Center(
        child: AnimatedSlide(
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
                // Wordmark — Playfair Display, gilded.
                Text(
                  'Long Ký',
                  style: VSType.hero.copyWith(
                    fontSize: 40,
                    color: VSColors.goldBright,
                    letterSpacing: 0.5,
                    shadows: const <Shadow>[
                      Shadow(color: Color(0x66000000), blurRadius: 16),
                    ],
                  ),
                ),
                const SizedBox(height: VSSpacing.md),
                Container(width: 40, height: 1, color: VSColors.goldBorder),
                const SizedBox(height: VSSpacing.md),
                Text('NGHÌN NĂM SỬ VIỆT', style: VSType.kicker),
                const SizedBox(height: VSSpacing.lg),
                AnimatedOpacity(
                  opacity: showProgress ? 1 : 0,
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
                      width: 120 * progress.clamp(0, 1),
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
        ),
      ),
    );
  }
}
