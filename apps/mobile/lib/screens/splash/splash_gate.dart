import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ui_kit/ui_kit.dart';

/// Wraps the app and shows the **Long Ký** brand splash over it on launch, then
/// fades away to reveal [child].
///
/// It lives only in the real app entry (`VietSuApp`) via `MaterialApp.router`'s
/// `builder`, so the widget-test harness — which mounts screens through its own
/// router — never sees it and never has to wait out its timers.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child});

  final Widget child;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _present = true; // overlay still in the tree
  bool _contentIn = false; // logo + wordmark have risen in
  bool _fadingOut = false; // whole overlay fading away

  final List<Timer> _timers = <Timer>[];

  @override
  void initState() {
    super.initState();
    _timers.add(Timer(const Duration(milliseconds: 90),
        () => setState(() => _contentIn = true)));
    _timers.add(Timer(const Duration(milliseconds: 1950),
        () => setState(() => _fadingOut = true)));
    _timers.add(Timer(const Duration(milliseconds: 2600),
        () => setState(() => _present = false)));
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
                child: _SplashScreen(contentIn: _contentIn),
              ),
            ),
          ),
      ],
    );
  }
}

/// The Long Ký splash: the seal on a deep lacquer ground, the wordmark below.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen({required this.contentIn});

  final bool contentIn;

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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
