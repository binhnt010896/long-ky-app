import 'dart:async';

import 'package:core_content/core_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:viet_su/state/firestore_content_source.dart';
import 'package:viet_su/state/firestore_content_sync.dart';
import 'package:viet_su/state/providers.dart';

/// An in-memory [LiveContentSource] so these tests never touch a real
/// Firestore backend — only [FirestoreContentSync]'s wiring is under test
/// here (the swap-timing logic itself is content_swap_gate_test.dart's job).
class _FakeLiveSource implements LiveContentSource {
  final _controller = StreamController<void>.broadcast();

  void fireChange() => _controller.add(null);

  @override
  Stream<void> changes() => _controller.stream;

  @override
  Future<List<String>> availableSlugs() async => const [];
  @override
  Future<String> loadEraJson(String slug) async =>
      throw ContentSourceException('not in fake');
  @override
  Future<String> loadPeopleJson() async =>
      throw ContentSourceException('not in fake');
  @override
  Future<String> loadPeriodsJson() async =>
      throw ContentSourceException('not in fake');
  @override
  Future<String> loadStandaloneEventsJson() async =>
      throw ContentSourceException('not in fake');
}

GoRouter _routerAt(String location) => GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(path: '/', builder: (_, __) => const SizedBox.shrink()),
        GoRoute(
          path: '/sanh',
          builder: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );

/// [FirestoreContentSync] needs a real [Ref], not a [ProviderContainer] —
/// this reads it out through a throwaway provider so tests can still build
/// one directly, matching how `firestoreContentSyncProvider` does it for
/// real in the app.
FirestoreContentSync _build(
  ProviderContainer container, {
  required GoRouter router,
  required LiveContentSource source,
  required bool enabled,
}) {
  final provider = Provider<FirestoreContentSync>(
    (ref) => FirestoreContentSync(
      router: router,
      ref: ref,
      source: source,
      enabled: enabled,
    ),
  );
  return container.read(provider);
}

void main() {
  test('disabled (no Firebase app) never touches the router or the source',
      () {
    final router = _routerAt('/');
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final source = _FakeLiveSource();

    final sync = _build(container, router: router, source: source, enabled: false);

    // No listener attached — firing a change must not crash or do anything.
    source.fireChange();
    sync.dispose(); // must not throw even though nothing was wired up.
  });

  test('installs itself as the content repository liveOverlay when enabled',
      () {
    final bundled = _StubBundled();
    final ota = OtaContentSource(bundled: bundled);
    final router = _routerAt('/');
    final container = ProviderContainer(
      overrides: [
        contentRepositoryProvider.overrideWithValue(ContentRepository(ota)),
      ],
    );
    addTearDown(container.dispose);
    final source = _FakeLiveSource();

    _build(container, router: router, source: source, enabled: true);

    expect(identical(ota.liveOverlay, source), isTrue);
  });

  test('a change on Home invalidates the content repository at once',
      () async {
    final bundled = _StubBundled();
    final repo = _SpyRepository(OtaContentSource(bundled: bundled));
    final router = _routerAt('/'); // Home
    final container = ProviderContainer(
      overrides: [contentRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final source = _FakeLiveSource();

    _build(container, router: router, source: source, enabled: true);

    source.fireChange();
    await pumpEventQueue();

    expect(repo.invalidateCount, 1, reason: 'on Home — swaps immediately');
  });

  // GoRouter only resolves/reports its current location once it's actually
  // mounted in a widget tree (an unmounted router's currentConfiguration
  // stays empty forever, which reads as "on Home" and would make this test
  // pass for the wrong reason) — so this one test uses testWidgets to
  // mount it for real, unlike the others above.
  testWidgets('a change off Home waits for the next return to Home',
      (tester) async {
    final bundled = _StubBundled();
    final repo = _SpyRepository(OtaContentSource(bundled: bundled));
    final router = _routerAt('/sanh'); // not Home
    final container = ProviderContainer(
      overrides: [contentRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final source = _FakeLiveSource();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    _build(container, router: router, source: source, enabled: true);
    await tester.pumpAndSettle();

    source.fireChange();
    await tester.pumpAndSettle();
    expect(repo.invalidateCount, 0, reason: 'not on Home yet');

    router.go('/');
    await tester.pumpAndSettle();
    expect(repo.invalidateCount, 1, reason: 'now on Home — swaps');
  });
}

/// Counts [invalidate] calls, so a test can assert *when* a swap happened
/// without depending on unrelated provider-graph reads.
class _SpyRepository extends ContentRepository {
  _SpyRepository(super.source);
  int invalidateCount = 0;

  @override
  void invalidate() {
    invalidateCount++;
    super.invalidate();
  }
}

/// A [ContentSource] with just enough real content to exercise
/// [ContentRepository.loadPeriods], counting how many times it's actually
/// re-read (vs. served from the repository's own cache).
class _StubBundled implements ContentSource {
  int periodsReads = 0;

  @override
  Future<List<String>> availableSlugs() async => const [];
  @override
  Future<String> loadEraJson(String slug) async =>
      throw ContentSourceException('no eras in stub');
  @override
  Future<String> loadPeopleJson() async =>
      throw ContentSourceException('no people in stub');
  @override
  Future<String> loadPeriodsJson() async {
    periodsReads++;
    return '{"schemaVersion":1,"periods":[]}';
  }
  @override
  Future<String> loadStandaloneEventsJson() async =>
      '{"schemaVersion":1,"events":[]}';
}
