import 'telemetry.dart';

/// Sends every call to each of [backends] — Firebase and PostHog side by side
/// for the release that compares them. One backend failing (a method-channel
/// error, a plugin not registered) never stops the others or reaches the
/// caller.
class CompositeTelemetry implements Telemetry {
  const CompositeTelemetry(this.backends);

  final List<Telemetry> backends;

  Future<void> _each(Future<void> Function(Telemetry backend) call) async {
    await Future.wait(<Future<void>>[
      for (final backend in backends)
        Future<void>.sync(() => call(backend)).catchError((Object _) {}),
    ]);
  }

  @override
  Future<void> screen(String name, [Map<String, Object> params = const {}]) =>
      _each((b) => b.screen(name, params));

  @override
  Future<void> event(String name, [Map<String, Object> params = const {}]) =>
      _each((b) => b.event(name, params));

  @override
  Future<void> recordError(Object error, StackTrace stackTrace,
          {String? reason, bool fatal = false}) =>
      _each((b) => b.recordError(error, stackTrace, reason: reason, fatal: fatal));

  @override
  Future<void> setEnabled(bool enabled) => _each((b) => b.setEnabled(enabled));

  @override
  Future<void> setCommonProperty(String key, Object value) =>
      _each((b) => b.setCommonProperty(key, value));
}
