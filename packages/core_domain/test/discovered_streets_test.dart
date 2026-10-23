import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

MappedStreet _street(String id, List<StreetTarget> targets,
        {StreetStatus status = StreetStatus.approved}) =>
    MappedStreet(id: id, name: id, targets: targets, status: status);

StreetTarget _t(StreetTargetType type, String id) =>
    StreetTarget(type: type, id: id, era: 'e');

void main() {
  final streets = <MappedStreet>[
    _street('ly-tu-trong', [_t(StreetTargetType.person, 'ly-tu-trong')]),
    _street('dien-bien', [_t(StreetTargetType.event, 'dien-bien-phu')]),
    _street('nha-tran', [_t(StreetTargetType.era, 'nha-tran')]),
    _street('hai-ba-trung', [
      _t(StreetTargetType.person, 'trung-trac'),
      _t(StreetTargetType.person, 'trung-nhi'),
    ]),
    _street('pending', [_t(StreetTargetType.person, 'ly-tu-trong')],
        status: StreetStatus.suggested),
  ];

  group('discoveredStreetIds', () {
    test('nothing visited discovers nothing', () {
      expect(discoveredStreetIds(streets, const <String>{}), isEmpty);
    });

    test('a person, an event or an era visit discovers its street', () {
      final found = discoveredStreetIds(streets, <String>{
        VisitKey.person('ly-tu-trong'),
        VisitKey.event('dien-bien-phu'),
        VisitKey.era('nha-tran'),
      });
      expect(found, {'ly-tu-trong', 'dien-bien', 'nha-tran'});
    });

    test('one of several targets is enough', () {
      expect(
          discoveredStreetIds(streets, {VisitKey.person('trung-nhi')}),
          {'hai-ba-trung'});
    });

    test('a person key never matches an event with the same id', () {
      expect(discoveredStreetIds(streets, {VisitKey.event('ly-tu-trong')}),
          isEmpty);
    });

    test('a street that is not approved is never discovered', () {
      expect(
          discoveredStreetIds(streets, {VisitKey.person('ly-tu-trong')})
              .contains('pending'),
          isFalse);
    });
  });

  test('streetPickKeys holds people and events, not eras or unapproved', () {
    expect(streetPickKeys(streets), {
      VisitKey.person('ly-tu-trong'),
      VisitKey.event('dien-bien-phu'),
      VisitKey.person('trung-trac'),
      VisitKey.person('trung-nhi'),
    });
  });
}
