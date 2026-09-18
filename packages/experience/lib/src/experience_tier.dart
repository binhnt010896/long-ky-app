import 'package:flutter/widgets.dart';

/// How richly the immersive layer runs. This is the single axis the whole widget
/// tree branches on — **never branch on `Platform`**. One widget tree, three
/// fidelities; each screen must work at every tier it can be shown in.
///
///  - [flagship]  — tilt parallax, Rive, drifting particles. Runtime decision on
///                  capable devices (e.g. Android API 29 + Vulkan, modern iOS).
///  - [reduced]   — no tilt, no particles; Rive falls back to static art.
///  - [trailer]   — the web/preview slice: static, lightweight, a couple of eras.
enum ExperienceTier { flagship, reduced, trailer }

/// The concrete capabilities a tier grants. Widgets query this instead of
/// assuming a feature exists ("query the tier, never assume the capability").
@immutable
class TierCapabilities {
  const TierCapabilities({
    required this.tilt,
    required this.particles,
    required this.rive,
    required this.parallax,
  });

  /// Device-tilt drives the parallax (gyro/accelerometer).
  final bool tilt;

  /// Ambient drifting particles are drawn.
  final bool particles;

  /// Rive animations play (else their static fallback image is used).
  final bool rive;

  /// Any parallax motion at all (tilt on flagship; pointer/drag elsewhere).
  final bool parallax;

  static const TierCapabilities _flagship = TierCapabilities(
    tilt: true,
    particles: true,
    rive: true,
    parallax: true,
  );

  static const TierCapabilities _reduced = TierCapabilities(
    tilt: false,
    particles: false,
    rive: false,
    parallax: true, // pointer/drag-driven, not tilt
  );

  static const TierCapabilities _trailer = TierCapabilities(
    tilt: false,
    particles: false,
    rive: false,
    parallax: false,
  );

  /// The capabilities for [tier].
  factory TierCapabilities.of(ExperienceTier tier) => switch (tier) {
        ExperienceTier.flagship => _flagship,
        ExperienceTier.reduced => _reduced,
        ExperienceTier.trailer => _trailer,
      };
}

extension ExperienceTierX on ExperienceTier {
  TierCapabilities get capabilities => TierCapabilities.of(this);
}

/// Provides the active [ExperienceTier] to the subtree.
///
/// The tier is a *runtime* decision made once near the app root (device probe,
/// user override, or trailer build) and threaded down here. Screens read it via
/// `ExperienceScope.of(context)` / `context.tier`.
class ExperienceScope extends InheritedWidget {
  const ExperienceScope({
    required this.tier,
    required super.child,
    super.key,
  });

  final ExperienceTier tier;

  static ExperienceTier of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ExperienceScope>();
    assert(scope != null, 'No ExperienceScope found in context');
    return scope!.tier;
  }

  /// Read the tier without registering a dependency (rare; prefer [of]).
  static ExperienceTier? maybeOf(BuildContext context) => context
      .getInheritedWidgetOfExactType<ExperienceScope>()
      ?.tier;

  @override
  bool updateShouldNotify(ExperienceScope oldWidget) => tier != oldWidget.tier;
}

extension ExperienceContext on BuildContext {
  /// The active experience tier.
  ExperienceTier get tier => ExperienceScope.of(this);

  /// The active tier's capabilities.
  TierCapabilities get caps => ExperienceScope.of(this).capabilities;
}
