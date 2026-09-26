import 'package:go_router/go_router.dart';

import 'telemetry.dart';

/// One resolved screen view: a fixed [name] (see app_router.dart's route
/// list) plus the small set of id params that route carries.
typedef ScreenView = ({String name, Map<String, Object> params});

/// Maps a go_router location to the fixed screen name + params it logs as.
/// Pure and independently testable — every route in app_router.dart must
/// have an entry here (see the table in EXECUTION.md's Cycle F).
///
/// Returns null for a location this app doesn't recognise (defensive; should
/// not happen with routes that are all defined in app_router.dart).
ScreenView? mapUriToScreen(Uri uri) {
  final segments = uri.pathSegments;
  final q = uri.queryParameters;

  String? paramOrNull(String key) {
    final v = q[key];
    return (v == null || v.isEmpty) ? null : v;
  }

  Map<String, Object> params(Map<String, String?> raw) => <String, Object>{
        for (final e in raw.entries)
          if (e.value != null) e.key: e.value!,
      };

  if (segments.isEmpty) return (name: 'home', params: const <String, Object>{});

  switch (segments.first) {
    case 'timeline':
      if (segments.length == 1) {
        return (name: 'global_timeline', params: const <String, Object>{});
      }
      return null;
    case 'map':
      if (segments.length == 1) {
        return (
          name: 'atlas',
          params: params(<String, String?>{'era_slug': paramOrNull('era')}),
        );
      }
      return null;
    case 'sanh':
      if (segments.length == 1) {
        return (name: 'sanh', params: const <String, Object>{});
      }
      if (segments.length == 2 && segments[1] == 'gioi-thieu') {
        return (name: 'about', params: const <String, Object>{});
      }
      if (segments.length == 2 && segments[1] == 'cau-do') {
        return (name: 'quiz_home', params: const <String, Object>{});
      }
      if (segments.length == 3 &&
          segments[1] == 'cau-do' &&
          segments[2] == 'choi') {
        return (
          name: 'quiz_play',
          params: params(<String, String?>{
            'quiz_mode': paramOrNull('mode'),
            'era_slug': paramOrNull('era'),
            'period_id': paramOrNull('period'),
          }),
        );
      }
      return null;
    case 'chao-co':
      if (segments.length == 1) {
        return (name: 'chao_co', params: const <String, Object>{});
      }
      return null;
    case 'era':
      if (segments.length == 2) {
        return (
          name: 'era_hub',
          params: <String, Object>{'era_slug': segments[1]},
        );
      }
      if (segments.length == 3 && segments[2] == 'timeline') {
        return (
          name: 'era_timeline',
          params: <String, Object>{'era_slug': segments[1]},
        );
      }
      if (segments.length == 4 && segments[2] == 'event') {
        return (
          name: 'event_detail',
          params: <String, Object>{
            'era_slug': segments[1],
            'event_id': segments[3],
          },
        );
      }
      if (segments.length == 4 && segments[2] == 'figure') {
        return (
          name: 'figure_detail',
          params: <String, Object>{
            'era_slug': segments[1],
            'figure_id': segments[3],
          },
        );
      }
      return null;
    default:
      return null;
  }
}

/// Logs a `screen_view` on every go_router navigation, keyed by the route
/// template rather than the raw path (so e.g. every event detail aggregates
/// under `event_detail` in GA4, with `era_slug`/`event_id` as dimensions).
///
/// Listens on the router itself (a [GoRouter] is a [Listenable] that notifies
/// on every navigation) rather than a [NavigatorObserver] — go_router's
/// nested routes don't reliably carry a route name through that API.
class RouteTelemetryObserver {
  RouteTelemetryObserver(this._router, this._telemetry) {
    _router.routerDelegate.addListener(_onRouteChanged);
    _onRouteChanged();
  }

  final GoRouter _router;
  final Telemetry _telemetry;
  String? _lastKey;

  void _onRouteChanged() {
    // currentConfiguration.uri (not routeInformationProvider, which only
    // reliably updates for the OS/browser-facing "top" navigation) reflects
    // every push/pop/go, including nested routes.
    final uri = _router.routerDelegate.currentConfiguration.uri;
    final view = mapUriToScreen(uri);
    if (view == null) return;
    final key = '${view.name}?${view.params}';
    if (key == _lastKey) return;
    _lastKey = key;
    _telemetry.screen(view.name, view.params);
  }

  void dispose() => _router.routerDelegate.removeListener(_onRouteChanged);
}
