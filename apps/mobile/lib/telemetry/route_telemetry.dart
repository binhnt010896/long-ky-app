import 'package:flutter/widgets.dart' show AppLifecycleListener, AppLifecycleState;
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
    case 'duong-pho':
      if (segments.length == 1) {
        return (
          name: 'street_map',
          params: params(<String, String?>{'street_id': paramOrNull('street')}),
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
    case 'su-kien':
      // A standalone event (no era). An event in an era never gets here: its
      // /su-kien/:id is redirected to /era/:slug/event/:id before any
      // location exists, so it logs as that route instead.
      if (segments.length == 2) {
        return (
          name: 'event_detail',
          params: <String, Object>{'event_id': segments[1]},
        );
      }
      return null;
    case 'nhan-vat':
      // A standalone person (no era). A rostered person is redirected to
      // /era/:slug/figure/:id before any location exists.
      if (segments.length == 2) {
        return (
          name: 'figure_detail',
          params: <String, Object>{'figure_id': segments[1]},
        );
      }
      return null;
    case 'hom-nay':
      // "Hôm nay" always redirects to the page it picked, so this is never the
      // logged location; it is mapped so every route has an entry.
      if (segments.length == 1) {
        return (name: 'today', params: const <String, Object>{});
      }
      return null;
    case 'luu-y':
      if (segments.length == 1) {
        return (name: 'disclaimer', params: const <String, Object>{});
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
///
/// Also times each screen: when the reader navigates away, or the app goes to
/// the background, it logs `screen_leave` with the screen's name and params,
/// `duration_ms` (foreground time only) and `reason` (`navigate` /
/// `background`). Logging on background too means a session that ends with
/// the app killed in the background still reports its last screen; on resume
/// the same screen starts a fresh timing without a second screen view.
///
/// Two hooks for screens whose content changes without the route changing:
/// [showInPlace] (the event pager's swipe — the swiped-to event logs its own
/// screen view and timing) and [annotate] (reading depth, added to the
/// current screen's `screen_leave`).
class RouteTelemetryObserver {
  RouteTelemetryObserver(this._router, this._telemetry,
      {DateTime Function()? clock})
      : _now = clock ?? DateTime.now {
    _router.routerDelegate.addListener(_onRouteChanged);
    _lifecycle = AppLifecycleListener(onStateChange: appLifecycleChanged);
    _onRouteChanged();
  }

  final GoRouter _router;
  final Telemetry _telemetry;
  final DateTime Function() _now;
  late final AppLifecycleListener _lifecycle;
  String? _lastKey;

  /// The screen on display, and since when it has been in the foreground
  /// (null while the app is in the background).
  ScreenView? _current;
  DateTime? _shownSince;
  bool _foreground = true;

  /// What [annotate] added for the current screen; reset on every new one.
  final Map<String, Object> _extras = <String, Object>{};

  /// Location → the view [showInPlace] put there, so returning to that
  /// location (popping a figure page pushed over a swiped-to event) logs what
  /// is actually on screen rather than the event the route first opened.
  final Map<String, ScreenView> _inPlace = <String, ScreenView>{};

  // currentConfiguration.uri (not routeInformationProvider, which only
  // reliably updates for the OS/browser-facing "top" navigation) reflects
  // every push/pop/go, including nested routes.
  Uri get _uri => _router.routerDelegate.currentConfiguration.uri;

  void _onRouteChanged() {
    final uri = _uri;
    final view = _inPlace[uri.toString()] ?? mapUriToScreen(uri);
    if (view == null) return;
    _show(view, 'navigate');
  }

  void _show(ScreenView view, String leaveReason) {
    final key = '${view.name}?${view.params}';
    if (key == _lastKey) return;
    _lastKey = key;
    _leave(leaveReason);
    _extras.clear();
    _current = view;
    _shownSince = _foreground ? _now() : null;
    _telemetry.screen(view.name, view.params);
  }

  /// The content on the current route changed to [view] without a
  /// navigation — logs it as a new screen (the previous one's `screen_leave`
  /// has reason `swipe`). Returns the location it is remembered under; pass
  /// it to [clearInPlace] when the screen that called this goes away.
  String showInPlace(ScreenView view) {
    final location = _uri.toString();
    _inPlace[location] = view;
    _show(view, 'swipe');
    return location;
  }

  void clearInPlace(String location) => _inPlace.remove(location);

  /// Adds [extras] to the `screen_leave` the current screen will log, if the
  /// current screen is [name] and its params include every entry of [match]
  /// — so a page left mounted under a pushed route can't annotate the route
  /// on top of it.
  void annotate(
      String name, Map<String, Object> match, Map<String, Object> extras) {
    final current = _current;
    if (current == null || current.name != name) return;
    for (final e in match.entries) {
      if (current.params[e.key] != e.value) return;
    }
    _extras.addAll(extras);
  }

  /// Public so tests can drive it; in the app the [AppLifecycleListener]
  /// calls it. `hidden` arrives before `paused` on every platform that has
  /// both, so whichever comes first ends the timing and the other is a no-op.
  void appLifecycleChanged(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (!_foreground) return;
        _leave('background');
        _foreground = false;
      case AppLifecycleState.resumed:
        if (_foreground) return;
        _foreground = true;
        if (_current != null) _shownSince = _now();
      case AppLifecycleState.inactive:
        // A dialog, the notification shade, the app switcher's first frame:
        // the screen is still on view.
        break;
    }
  }

  void _leave(String reason) {
    final current = _current;
    final since = _shownSince;
    _shownSince = null;
    if (current == null || since == null) return;
    final ms = _now().difference(since).inMilliseconds;
    if (ms < 0) return;
    _telemetry.event('screen_leave', <String, Object>{
      'screen': current.name,
      ...current.params,
      ..._extras,
      'duration_ms': ms,
      'reason': reason,
    });
  }

  void dispose() {
    _router.routerDelegate.removeListener(_onRouteChanged);
    _lifecycle.dispose();
  }
}
