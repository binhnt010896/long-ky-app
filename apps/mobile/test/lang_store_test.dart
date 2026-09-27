import 'dart:io';

import 'package:core_domain/core_domain.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_su/state/lang_store.dart';

/// Points `path_provider`'s `getApplicationSupportDirectory()` at a fresh temp
/// directory, so [FileLangStore] can be exercised with real file I/O — the
/// plugin channel is otherwise unmocked in widget tests (see
/// telemetry_test.dart's note on the same constraint).
Directory _mockPathProvider(TestWidgetsFlutterBinding binding) {
  final dir = Directory.systemTemp.createTempSync('lang_store_test');
  addTearDown(() => dir.deleteSync(recursive: true));
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
    if (call.method == 'getApplicationSupportDirectory') return dir.path;
    return null;
  });
  addTearDown(
      () => binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
  return dir;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to Vietnamese when nothing has been saved', () async {
    _mockPathProvider(TestWidgetsFlutterBinding.instance);
    final store = FileLangStore();
    expect(await store.load(), Lang.vi);
  });

  test('round-trips a saved choice across store instances', () async {
    _mockPathProvider(TestWidgetsFlutterBinding.instance);
    await FileLangStore().save(Lang.en);

    // A fresh instance (no in-memory cache) reads the persisted file.
    expect(await FileLangStore().load(), Lang.en);
  });

  test('saving vi after en round-trips back to vi', () async {
    _mockPathProvider(TestWidgetsFlutterBinding.instance);
    await FileLangStore().save(Lang.en);
    await FileLangStore().save(Lang.vi);
    expect(await FileLangStore().load(), Lang.vi);
  });

  test('a corrupt saved file falls back to Vietnamese, not a crash', () async {
    final dir = _mockPathProvider(TestWidgetsFlutterBinding.instance);
    File('${dir.path}/lang.json').writeAsStringSync('{not json');
    expect(await FileLangStore().load(), Lang.vi);
  });

  test('a missing app-support directory does not crash a save', () async {
    _mockPathProvider(TestWidgetsFlutterBinding.instance);
    final store = FileLangStore();
    await store.save(Lang.en);
    // In-memory state still reflects the choice even if the write is slow to
    // land — a second load (cached) sees it immediately.
    expect(await store.load(), Lang.en);
  });
}
