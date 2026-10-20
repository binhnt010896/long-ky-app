import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_su/state/onboarding_store.dart';

void _mockPathProvider(TestWidgetsFlutterBinding binding) {
  final dir = Directory.systemTemp.createTempSync('onboarding_store_test');
  addTearDown(() => dir.deleteSync(recursive: true));
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
    call,
  ) async {
    if (call.method == 'getApplicationSupportDirectory') return dir.path;
    return null;
  });
  addTearDown(
    () =>
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the tour is unseen on a fresh install', () async {
    _mockPathProvider(TestWidgetsFlutterBinding.instance);
    expect(await FileOnboardingStore().homeTourSeen(), isFalse);
  });

  test('seen survives a relaunch, and reset brings the tour back', () async {
    _mockPathProvider(TestWidgetsFlutterBinding.instance);
    await FileOnboardingStore().markHomeTourSeen();
    expect(await FileOnboardingStore().homeTourSeen(), isTrue);

    await FileOnboardingStore().resetHomeTour();
    expect(await FileOnboardingStore().homeTourSeen(), isFalse);
  });

  test('a reader who finished an older tour version is not "seen" and keeps their version',
      () async {
    final binding = TestWidgetsFlutterBinding.instance;
    final dir = Directory.systemTemp.createTempSync('onboarding_v1');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/onboarding.json').writeAsStringSync('{"homeTour":1}');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async =>
        call.method == 'getApplicationSupportDirectory' ? dir.path : null);
    addTearDown(() =>
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

    final store = FileOnboardingStore();
    expect(await store.homeTourVersion(), 1);
    expect(await store.homeTourSeen(), isFalse);
    await store.markHomeTourSeen();
    expect(await FileOnboardingStore().homeTourVersion(), kHomeTourVersion);
  });

  test('the Sảnh-visited flag persists and survives resetting the tour', () async {
    _mockPathProvider(TestWidgetsFlutterBinding.instance);
    expect(await FileOnboardingStore().sanhVisited(), isFalse);
    await FileOnboardingStore().markSanhVisited();
    expect(await FileOnboardingStore().sanhVisited(), isTrue);
    await FileOnboardingStore().resetHomeTour();
    expect(await FileOnboardingStore().sanhVisited(), isTrue);
  });
}
