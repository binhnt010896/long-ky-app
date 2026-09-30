import 'dart:async';

import 'package:core_content/core_content.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app_router.dart';
import 'content_swap_gate.dart';
import 'firestore_content_source.dart';
import 'providers.dart';

/// Wires Firestore's live content updates (Cycle K5) into the running app:
/// installs a [FirestoreContentSource] as the content repository's
/// [OtaContentSource.liveOverlay], listens for changes, and — gated by
/// [ContentSwapGate] so era/event text never changes under a reader
/// mid-session (K6) — invalidates the content caches at the right moment.
/// One instance for the app's whole lifetime, same pattern as
/// `RouteTelemetryObserver`.
class FirestoreContentSync {
  /// [enabled] defaults to whether a Firebase app has actually been
  /// initialized — today that's release-mode, non-web only (see
  /// `main.dart`), matching the rest of Firebase usage in this app.
  /// Touching `FirebaseFirestore.instance` with no app initialized throws,
  /// so this must be checked before constructing [FirestoreContentSource]
  /// at all, not just before using it.
  factory FirestoreContentSync({
    required GoRouter router,
    required Ref ref,
    LiveContentSource? source,
    bool? enabled,
  }) {
    return FirestoreContentSync._(
      router: router,
      ref: ref,
      enabled: enabled ?? Firebase.apps.isNotEmpty,
      source: source,
    );
  }

  FirestoreContentSync._({
    required GoRouter router,
    required Ref ref,
    required bool enabled,
    LiveContentSource? source,
    // An initializing formal here would force callers of this private
    // constructor to use the `_`-prefixed field name too.
  })  : _router = router, // ignore: prefer_initializing_formals
        _ref = ref,
        _enabled = enabled,
        _source = enabled ? (source ?? FirestoreContentSource()) : null {
    if (!_enabled) return; // No Firebase app — stay a no-op (see above).
    final repoSource = ref.read(contentRepositoryProvider).source;
    if (repoSource is OtaContentSource) {
      repoSource.liveOverlay = _source;
    }
    _gate = ContentSwapGate(onSwap: _swap);
    _router.routerDelegate.addListener(_onRouteChanged);
    _onRouteChanged();
    _sub = _source!.changes().listen((_) => _gate!.contentChanged());
  }

  final GoRouter _router;
  final Ref _ref;
  final bool _enabled;
  final LiveContentSource? _source;
  ContentSwapGate? _gate;
  StreamSubscription<void>? _sub;

  void _onRouteChanged() {
    // Mirrors route_telemetry.dart's own reasoning for reading
    // currentConfiguration.uri rather than routeInformationProvider — it's
    // the one that reliably reflects every push/pop/go, nested routes
    // included.
    final uri = _router.routerDelegate.currentConfiguration.uri;
    _gate?.routeChanged(onHome: uri.pathSegments.isEmpty);
  }

  void _swap() {
    final repo = _ref.read(contentRepositoryProvider);
    repo.invalidate();
    _ref.invalidate(dynastiesProvider);
    _ref.invalidate(erasProvider);
    _ref.invalidate(periodsProvider);
    _ref.invalidate(eraProvider);
    _ref.invalidate(standaloneEventsProvider);
    _ref.invalidate(eventLocationProvider);
  }

  void dispose() {
    if (!_enabled) return;
    _router.routerDelegate.removeListener(_onRouteChanged);
    _sub?.cancel();
  }
}

/// One [FirestoreContentSync] for the app's whole lifetime — watched once
/// from [VietSuApp] purely to construct it (its work is side effects, not a
/// value anyone reads).
final firestoreContentSyncProvider = Provider<FirestoreContentSync>((ref) {
  final sync = FirestoreContentSync(router: ref.watch(routerProvider), ref: ref);
  ref.onDispose(sync.dispose);
  return sync;
});
