/// The PostHog project the app reports to ("Long Ky", US cloud). The project
/// token is a public, write-only client key — it can only send events, never
/// read them — so like firebase_options.dart it lives in source.
abstract final class PostHogOptions {
  static const String projectToken =
      'phc_zEBAHqRBPL9HK8HHAzQxmPQKLzmkFhK2RBdKbLfeCiAE';
  static const String host = 'https://us.i.posthog.com';
}

/// `--dart-define=TELEMETRY_DEBUG=true` turns PostHog on in a debug build, so
/// a change to the event taxonomy can be checked in PostHog's live events view
/// from a device. Those events carry `debug_build: true` and are excluded by
/// the project's test-account filter. Firebase stays off in debug either way.
const bool kTelemetryDebug = bool.fromEnvironment('TELEMETRY_DEBUG');
