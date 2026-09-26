import 'dart:typed_data';

import 'package:admin/state/media_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('markReplaced is visible to every reader of the shared provider', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(mediaSessionProvider), isEmpty);

    final bytes = Uint8List.fromList([1, 2, 3]);
    container.read(mediaSessionProvider.notifier).markReplaced('eras/x/cover.png', bytes);

    // Any screen watching the same path — Media library, the Era page's
    // Images tab, the Period pane, People — sees the same replacement.
    expect(container.read(mediaSessionProvider)['eras/x/cover.png'], bytes);
  });

  test('replacing a second path does not disturb the first', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(mediaSessionProvider.notifier);

    notifier.markReplaced('a.png', Uint8List.fromList([1]));
    notifier.markReplaced('b.png', Uint8List.fromList([2]));

    final state = container.read(mediaSessionProvider);
    expect(state['a.png'], Uint8List.fromList([1]));
    expect(state['b.png'], Uint8List.fromList([2]));
  });
}
