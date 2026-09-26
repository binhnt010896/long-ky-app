import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_telemetry.dart';

/// The one seam every screen/action logs through — screen views, the small
/// fixed event taxonomy, and non-fatal/fatal error reports. Never collects
/// anything that identifies a person: no user id, no advertising id, no
/// freeform text.
///
/// [FirebaseTelemetry] is the real, on-device implementation (Android release
/// builds only); [NoopTelemetry] backs web, debug builds and tests, so our
/// own testing and the web dev-verification target never pollute the numbers.
abstract class Telemetry {
  /// Logs a screen view. [name] is a fixed screen key (see route_telemetry.dart
  /// for the route → name mapping), never freeform text.
  Future<void> screen(String name, [Map<String, Object> params]);

  /// Logs one of the fixed taxonomy events (see EXECUTION.md's Cycle F event
  /// table). [name] and the keys of [params] must be from that fixed list.
  Future<void> event(String name, [Map<String, Object> params]);

  /// Records a non-fatal error with a short [reason] for context (e.g. which
  /// store/operation failed). Never rethrows, never blocks the caller.
  Future<void> recordError(Object error, StackTrace stackTrace,
      {String? reason, bool fatal = false});

  /// Turns collection on/off at runtime — wired to the Về Long Ký switch.
  /// Applies to both Analytics and Crashlytics collection.
  Future<void> setEnabled(bool enabled);
}

/// Collects nothing. Used on web (no Firebase configuration there — see
/// firebase_options.dart), in debug builds (so local testing never appears in
/// the real numbers), and as the default in tests.
class NoopTelemetry implements Telemetry {
  const NoopTelemetry();

  @override
  Future<void> screen(String name, [Map<String, Object> params = const {}]) async {}

  @override
  Future<void> event(String name, [Map<String, Object> params = const {}]) async {}

  @override
  Future<void> recordError(Object error, StackTrace stackTrace,
      {String? reason, bool fatal = false}) async {}

  @override
  Future<void> setEnabled(bool enabled) async {}
}

/// Picks the real implementation only where it can actually run: a release
/// build, on a platform Firebase is configured for (Android only — iOS stays
/// parked, web throws in firebase_options.dart by design).
final telemetryProvider = Provider<Telemetry>((ref) {
  if (kIsWeb || !kReleaseMode) return const NoopTelemetry();
  return FirebaseTelemetry();
});

/// A free function for the plain-Dart stores that have no [WidgetRef]
/// (`ContentSync`, `TipStore`, `MediaPrefetcher`, `QuizStore`) — call it from
/// a `catch` that already swallows the error for the user, so it's *also*
/// visible in Crashlytics as non-fatal. No-ops on web/debug, matching
/// [telemetryProvider]'s own gating; never rethrows.
void reportNonFatal(Object error, StackTrace stackTrace, {required String reason}) {
  if (kIsWeb || !kReleaseMode) return;
  try {
    FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: reason);
  } catch (_) {
    // Reporting the report failing is not worth doing.
  }
}
