import 'package:core_content/core_content.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_su/state/bundled_content.dart';

/// The app's own wiring, through the real asset bundle — exactly what a phone
/// does at startup. Every other test swaps in a disk source, which is how a
/// missing `events.json` path in the real construction once went unnoticed: all
/// the tests were green while every era failed to load in the running app.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the bundled baseline loads every era, with every event', () async {
    final repo = ContentRepository(appBundledContent());
    final eras = await repo.loadAllEras();
    expect(eras, hasLength(38));
    expect(eras.fold<int>(0, (n, e) => n + e.events.length), 237);
    // Reading order survived the trip through the registry.
    for (final era in eras) {
      expect([for (final e in era.events) e.order],
          [for (var i = 0; i < era.events.length; i++) i],
          reason: era.slug);
    }
  });

  test('no event is left as a bare ref — the first event has its full content', () async {
    final era = await ContentRepository(appBundledContent()).loadEra('nha-trieu');
    expect(era.events.first.title.vi, isNotEmpty);
    expect(era.events.first.citation.work, isNotEmpty);
  });

  test('the standalone events (listed by no era) load from the registry', () async {
    final repo = ContentRepository(appBundledContent());
    final ids = [for (final e in await repo.loadStandaloneEvents()) e.id];
    expect(ids, hasLength(10));
    expect(ids, contains('nguyen-huu-canh-lap-phu-gia-dinh'));
    expect(ids, contains('dac-cong-rung-sac'));
  });

  test('findEvent locates an in-era event through the bundled registry', () async {
    final found = await ContentRepository(appBundledContent())
        .findEvent('trieu-vu-de-lap-nam-viet');
    expect(found?.era?.slug, 'nha-trieu');
  });
}
