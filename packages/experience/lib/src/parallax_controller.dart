import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// A normalized parallax pointer in the range [-1, 1] on each axis.
///
/// `(0, 0)` is rest. One controller feeds one [ParallaxScene]; the scene listens
/// to exactly this notifier, so the parallax path is a single rebuild per frame.
class ParallaxController extends ValueNotifier<Offset> {
  ParallaxController() : super(Offset.zero);

  /// Set the pointer directly (e.g. from a drag), clamped to the unit square.
  void set(Offset value) {
    this.value = Offset(
      value.dx.clamp(-1.0, 1.0),
      value.dy.clamp(-1.0, 1.0),
    );
  }
}

/// Drives a [ParallaxController] from device tilt (accelerometer gravity vector).
///
/// Flagship tier only. On devices/emulators that emit no sensor data the pointer
/// simply stays at rest — the scene degrades to static without any branch. The
/// signal is low-pass filtered so the scene drifts rather than jitters.
class TiltParallaxDriver {
  TiltParallaxDriver(
    this.controller, {
    this.sensitivity = 0.18,
    this.smoothing = 0.12,
  });

  final ParallaxController controller;

  /// How far a given tilt pushes the pointer. Higher = more motion.
  final double sensitivity;

  /// Low-pass factor 0..1; smaller = smoother/slower to follow.
  final double smoothing;

  StreamSubscription<AccelerometerEvent>? _sub;
  Offset _filtered = Offset.zero;

  void start() {
    _sub ??= accelerometerEventStream().listen(_onEvent, onError: (_) {});
  }

  void _onEvent(AccelerometerEvent e) {
    // Portrait: e.x is left/right tilt, e.y is up/down. Normalize by gravity.
    final target = Offset(
      (-e.x / 9.8) * (sensitivity * 6),
      (e.y / 9.8) * (sensitivity * 6),
    );
    _filtered = Offset.lerp(_filtered, target, smoothing)!;
    controller.set(_filtered);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
