import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_su/screens/splash/splash_gate.dart';

void main() {
  const window = Duration(seconds: 2);

  List<(int, bool)> run(Duration arrivesAfter, int? pack) {
    final adopted = <(int, bool)>[];
    fakeAsync((async) {
      final check = Future<int?>.delayed(arrivesAfter, () => pack);
      adoptPackWhenReady<int>(check,
          window: window, adopt: (p, {required live}) => adopted.add((p, live)));
      async.elapse(const Duration(seconds: 30));
    });
    return adopted;
  }

  test('a pack inside the window is adopted under the splash', () {
    expect(run(const Duration(milliseconds: 800), 7), [(7, false)]);
  });

  test('a pack after the window is adopted live, once', () {
    expect(run(const Duration(seconds: 6), 7), [(7, true)]);
  });

  test('no newer pack adopts nothing, early or late', () {
    expect(run(const Duration(milliseconds: 500), null), isEmpty);
    expect(run(const Duration(seconds: 6), null), isEmpty);
  });

  test('the caller is released at the window, not when the pack lands', () {
    fakeAsync((async) {
      var released = false;
      adoptPackWhenReady<int>(Completer<int?>().future,
              window: window, adopt: (_, {required live}) {})
          .then((_) => released = true);
      async.elapse(const Duration(milliseconds: 1999));
      expect(released, isFalse);
      async.elapse(const Duration(milliseconds: 2));
      expect(released, isTrue);
    });
  });

  group('shouldCheckOnResume', () {
    final t0 = DateTime(2026, 10, 6, 12);
    test('checks after the interval, not before', () {
      expect(shouldCheckOnResume(now: t0.add(const Duration(minutes: 29)), last: t0, busy: false), isFalse);
      expect(shouldCheckOnResume(now: t0.add(const Duration(minutes: 30)), last: t0, busy: false), isTrue);
    });
    test('never while a check is running', () {
      expect(shouldCheckOnResume(now: t0.add(const Duration(hours: 5)), last: t0, busy: true), isFalse);
    });
  });
}
