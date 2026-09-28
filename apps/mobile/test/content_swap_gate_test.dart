import 'package:flutter_test/flutter_test.dart';
import 'package:viet_su/state/content_swap_gate.dart';

void main() {
  test('a content change while on Home swaps immediately', () {
    var swaps = 0;
    final gate = ContentSwapGate(onSwap: () => swaps++);

    gate.contentChanged();

    expect(swaps, 1);
  });

  test('a content change off Home waits for the next return to Home', () {
    var swaps = 0;
    final gate = ContentSwapGate(onSwap: () => swaps++);
    gate.routeChanged(onHome: false);

    gate.contentChanged();
    expect(swaps, 0, reason: 'not on Home yet — must not swap under a reader');

    gate.routeChanged(onHome: false); // still elsewhere
    expect(swaps, 0);

    gate.routeChanged(onHome: true);
    expect(swaps, 1);
  });

  test('several changes before reaching Home collapse into one swap', () {
    var swaps = 0;
    final gate = ContentSwapGate(onSwap: () => swaps++);
    gate.routeChanged(onHome: false);

    gate.contentChanged();
    gate.contentChanged();
    gate.contentChanged();
    gate.routeChanged(onHome: true);

    expect(swaps, 1);
  });

  test('returning to Home with nothing pending does not swap', () {
    var swaps = 0;
    final gate = ContentSwapGate(onSwap: () => swaps++);
    gate.routeChanged(onHome: false);
    gate.routeChanged(onHome: true);

    expect(swaps, 0);
  });

  test('a second change after already swapping on Home swaps again', () {
    var swaps = 0;
    final gate = ContentSwapGate(onSwap: () => swaps++);

    gate.contentChanged();
    expect(swaps, 1);
    gate.contentChanged();
    expect(swaps, 2);
  });

  test('default state is "on Home" — a change before any route event swaps',
      () {
    // main.dart constructs this before the router has reported anything;
    // the very first content check (mirroring today's splash check) should
    // still be able to swap immediately rather than waiting forever for a
    // routeChanged that may never come if the reader never leaves Home.
    var swaps = 0;
    final gate = ContentSwapGate(onSwap: () => swaps++);

    gate.contentChanged();

    expect(swaps, 1);
  });
}
