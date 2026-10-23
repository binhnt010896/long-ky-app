import 'package:posthog_flutter/posthog_flutter.dart';

import 'posthog_options.dart';
import 'telemetry.dart';

/// Product analytics backed by PostHog: screen views, the fixed event
/// taxonomy, and the app-lifecycle events PostHog's DAU/retention/session
/// insights are built on. Runs alongside [FirebaseTelemetry] for one release
/// (see [CompositeTelemetry]); crashes stay in Crashlytics, so [recordError]
/// does nothing here.
///
/// Anonymous by construction: no person profiles, no identify, no replay, no
/// surveys — only PostHog's random per-install id, the same promise the
/// privacy policy makes for Firebase.
class PostHogTelemetry implements Telemetry {
  PostHogTelemetry._();

  final Posthog _posthog = Posthog();

  /// Sets up the SDK and returns the backend. [enabled] is the Về Long Ký
  /// switch: when off, the SDK starts opted out, so not even the
  /// `Application Opened` lifecycle event goes out before main.dart applies it.
  static Future<PostHogTelemetry> start({required bool enabled}) async {
    final config = PostHogConfig(PostHogOptions.projectToken)
      ..host = PostHogOptions.host
      ..optOut = !enabled
      ..personProfiles = PostHogPersonProfiles.never
      ..captureApplicationLifecycleEvents = true
      ..sessionReplay = false
      ..surveys = false
      // No feature flags in use: skip the /flags request every start makes.
      ..preloadFeatureFlags = false
      ..sendFeatureFlagEvent = false
      ..capturePushNotificationSubscriptions = false
      ..capturePushNotificationOpened = false;
    await Posthog().setup(config);
    return PostHogTelemetry._();
  }

  @override
  Future<void> screen(String name, [Map<String, Object> params = const {}]) {
    return _posthog.screen(
      screenName: name,
      properties: params.isEmpty ? null : params,
    );
  }

  @override
  Future<void> event(String name, [Map<String, Object> params = const {}]) {
    return _posthog.capture(
      eventName: name,
      properties: params.isEmpty ? null : params,
    );
  }

  @override
  Future<void> recordError(Object error, StackTrace stackTrace,
      {String? reason, bool fatal = false}) async {}

  @override
  Future<void> setEnabled(bool enabled) =>
      enabled ? _posthog.optIn() : _posthog.optOut();

  @override
  Future<void> setCommonProperty(String key, Object value) =>
      _posthog.register(key, value);
}
