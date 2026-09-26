import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'telemetry.dart';

/// Real telemetry, backed by Firebase Analytics + Crashlytics. Constructed
/// only after `Firebase.initializeApp` has run (see main.dart) and only on a
/// release Android build — see [telemetryProvider].
class FirebaseTelemetry implements Telemetry {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  @override
  Future<void> screen(String name, [Map<String, Object> params = const {}]) {
    return _analytics.logScreenView(
      screenName: name,
      parameters: params.isEmpty ? null : params,
    );
  }

  @override
  Future<void> event(String name, [Map<String, Object> params = const {}]) {
    return _analytics.logEvent(
      name: name,
      parameters: params.isEmpty ? null : params,
    );
  }

  @override
  Future<void> recordError(Object error, StackTrace stackTrace,
      {String? reason, bool fatal = false}) {
    return _crashlytics.recordError(
      error,
      stackTrace,
      reason: reason,
      fatal: fatal,
    );
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    await _analytics.setAnalyticsCollectionEnabled(enabled);
    await _crashlytics.setCrashlyticsCollectionEnabled(enabled);
  }
}
