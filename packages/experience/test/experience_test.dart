import 'package:experience/experience.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TierCapabilities', () {
    test('flagship enables tilt, particles, rive', () {
      final c = ExperienceTier.flagship.capabilities;
      expect(c.tilt, isTrue);
      expect(c.particles, isTrue);
      expect(c.rive, isTrue);
      expect(c.parallax, isTrue);
    });

    test('reduced drops tilt and particles but keeps parallax', () {
      final c = ExperienceTier.reduced.capabilities;
      expect(c.tilt, isFalse);
      expect(c.particles, isFalse);
      expect(c.rive, isFalse);
      expect(c.parallax, isTrue);
    });

    test('trailer is fully static', () {
      final c = ExperienceTier.trailer.capabilities;
      expect(c.tilt, isFalse);
      expect(c.particles, isFalse);
      expect(c.parallax, isFalse);
    });
  });

  group('ExperienceScope', () {
    testWidgets('provides the tier to descendants', (tester) async {
      late ExperienceTier seen;
      await tester.pumpWidget(
        ExperienceScope(
          tier: ExperienceTier.reduced,
          child: Builder(
            builder: (context) {
              seen = context.tier;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen, ExperienceTier.reduced);
    });
  });

  group('ParallaxController', () {
    test('clamps to the unit square', () {
      final c = ParallaxController();
      c.set(const Offset(3, -2));
      expect(c.value, const Offset(1, -1));
    });
  });

  group('ParallaxScene', () {
    testWidgets('near layers travel farther than far layers', (tester) async {
      final pointer = ParallaxController();
      final farKey = GlobalKey();
      final nearKey = GlobalKey();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 300,
              height: 300,
              child: ParallaxScene(
                pointer: pointer,
                maxShift: 100,
                layers: <ParallaxLayer>[
                  ParallaxLayer(
                    depth: 0.0,
                    child: SizedBox.expand(key: farKey),
                  ),
                  ParallaxLayer(
                    depth: 1.0,
                    child: SizedBox.expand(key: nearKey),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final farAtRest = tester.getTopLeft(find.byKey(farKey));
      final nearAtRest = tester.getTopLeft(find.byKey(nearKey));

      // Deflect the pointer fully to the right.
      pointer.set(const Offset(1, 0));
      await tester.pump();

      final farShift = tester.getTopLeft(find.byKey(farKey)).dx - farAtRest.dx;
      final nearShift =
          tester.getTopLeft(find.byKey(nearKey)).dx - nearAtRest.dx;

      expect(farShift, 0, reason: 'depth 0 layer does not move');
      expect(nearShift, moveTo(100), reason: 'depth 1 layer moves maxShift');
    });
  });
}

/// depth-1 layer should shift by maxShift (100), allowing for the overscale
/// transform which is applied about the centre and does not change top-left by
/// the translate amount.
Matcher moveTo(double expected) => closeTo(expected, 0.5);
