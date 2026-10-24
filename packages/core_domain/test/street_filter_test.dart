import 'dart:convert';

import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

MappedStreet _street(String id, List<StreetTarget> targets) => MappedStreet(
      id: id,
      name: id,
      targets: targets,
      status: StreetStatus.approved,
    );

StreetTarget _inEra(String era) =>
    StreetTarget(type: StreetTargetType.person, id: 'p-$era', era: era);
StreetTarget _inPeriod(String period) =>
    StreetTarget(type: StreetTargetType.person, id: 'p-$period', era: '', period: period);

const _periodOf = {'tran-hung-dao': 'nha-tran', 'le-loi': 'hau-le'};

void main() {
  group('StreetTarget.period', () {
    test('round-trips, and is left out of the JSON when empty', () {
      final t = StreetTarget.fromJson({
        'type': 'person',
        'id': 'nguyen-du',
        'era': '',
        'period': 'nguyen',
      });
      expect(t.period, 'nguyen');
      expect(t.toJson()['period'], 'nguyen');
      expect(StreetTarget.fromJson(t.toJson()), t);

      final plain = StreetTarget.fromJson(
          {'type': 'person', 'id': 'x', 'era': 'le-loi'});
      expect(plain.period, '');
      expect(plain.toJson().containsKey('period'), isFalse);
    });
  });

  group('buckets', () {
    test('an era target sits under its era and that era\'s period', () {
      final s = _street('a', [_inEra('tran-hung-dao')]);
      expect(bucketsOf(s, _periodOf),
          {const StreetBucket('nha-tran', 'tran-hung-dao')});
    });

    test('a standalone target sits under its own period; none → catch-all', () {
      expect(bucketsOf(_street('a', [_inPeriod('nguyen')]), _periodOf),
          {const StreetBucket('nguyen', '')});
      expect(bucketsOf(_street('a', [_inPeriod('')]), _periodOf),
          {const StreetBucket('', '')});
    });

    test('an era the registry does not know falls to the unknown period', () {
      expect(bucketsOf(_street('a', [_inEra('mystery')]), _periodOf),
          {const StreetBucket('', 'mystery')});
    });
  });

  group('visibleStreetIds', () {
    final streets = [
      _street('tran', [_inEra('tran-hung-dao')]),
      _street('loi', [_inEra('le-loi')]),
      _street('both', [_inEra('tran-hung-dao'), _inEra('le-loi')]),
      _street('nguyen', [_inPeriod('nguyen')]),
    ];

    test('nothing hidden shows everything', () {
      expect(visibleStreetIds(streets, {}, _periodOf),
          {'tran', 'loi', 'both', 'nguyen'});
    });

    test('hiding a bucket hides its streets', () {
      expect(
        visibleStreetIds(
            streets, {const StreetBucket('hau-le', 'le-loi')}, _periodOf),
        {'tran', 'both', 'nguyen'},
      );
    });

    test('a street named for two things stays while either is shown', () {
      final hidden = {const StreetBucket('nha-tran', 'tran-hung-dao')};
      expect(visibleStreetIds(streets, hidden, _periodOf).contains('both'),
          isTrue);
      final bothHidden = {
        const StreetBucket('nha-tran', 'tran-hung-dao'),
        const StreetBucket('hau-le', 'le-loi'),
      };
      expect(visibleStreetIds(streets, bothHidden, _periodOf).contains('both'),
          isFalse);
    });

    test('counts: a street counts once in each bucket it sits in', () {
      final c = countBuckets(streets, _periodOf);
      expect(c[const StreetBucket('nha-tran', 'tran-hung-dao')], 2);
      expect(c[const StreetBucket('hau-le', 'le-loi')], 2);
      expect(c[const StreetBucket('nguyen', '')], 1);
    });
  });

  group('buildFilterGroups', () {
    Era era(String slug, int order, String period) => Era(
          schemaVersion: 1,
          id: slug,
          slug: slug,
          order: order,
          period: period,
          title: LocalizedText(vi: 'Thời $slug', en: slug),
          kicker: const LocalizedText(vi: 'k'),
          subtitle: const LocalizedText(vi: 's'),
          yearRange: const YearRange(display: LocalizedText(vi: '1 – 2')),
          palette: const EraPalette(accent: '#000000'),
          primarySource: const Citation(work: 'w'),
          events: const [],
        );

    PeriodRegistry periods() => PeriodRegistry.fromJson({
          'periods': [
            for (final (i, id) in ['nha-tran', 'hau-le', 'nguyen'].indexed)
              {
                'id': id,
                'order': i,
                'title': {'vi': id, 'en': id},
                'kicker': {'vi': 'k', 'en': 'k'},
                'yearRange': {
                  'display': {'vi': '1 – 2', 'en': '1 – 2'},
                  'startYear': 1,
                  'endYear': 2,
                },
                'accent': '#000000',
              },
          ],
        });

    test('periods in order, only rows with streets, other-row last', () {
      final counts = {
        const StreetBucket('hau-le', 'le-loi'): 3,
        const StreetBucket('nha-tran', 'tran-hung-dao'): 2,
        const StreetBucket('nha-tran', ''): 1,
        const StreetBucket('', ''): 4,
      };
      final groups = buildFilterGroups(
        periods: periods(),
        eras: [era('le-loi', 1, 'hau-le'), era('tran-hung-dao', 0, 'nha-tran')],
        counts: counts,
      );
      expect([for (final g in groups) g.period], ['nha-tran', 'hau-le', '']);
      expect(
        [for (final r in groups.first.rows) r.bucket.era],
        ['tran-hung-dao', ''],
      );
      expect(groups.first.count, 3);
      // Every counted bucket is reachable through some row.
      final reachable = {
        for (final g in groups) for (final r in g.rows) r.bucket,
      };
      expect(reachable, counts.keys.toSet());
    });
  });

  group('validator: period', () {
    String file(List<Map<String, dynamic>> targets) => jsonEncode({
          'schemaVersion': 1,
          'city': 'hcm',
          'osmSnapshot': 't',
          'streets': [
            {'id': 's', 'name': 'S', 'status': 'approved', 'targets': targets},
          ],
        });

    List<String> run(List<Map<String, dynamic>> targets) =>
        StreetMapValidator.validate(
          streetsJson: file(targets),
          peopleIds: {'p'},
          eras: [
            {'slug': 'e', 'characters': <dynamic>[], 'events': <dynamic>[]},
          ],
          periodIds: {'nguyen'},
        );

    test('the reserved "other" period is fine and files under Other', () {
      expect(
        run([{'type': 'person', 'id': 'p', 'era': '', 'period': 'other'}]),
        isEmpty,
      );
    });

    test('a standalone person with a known period is fine', () {
      expect(
        run([{'type': 'person', 'id': 'p', 'era': '', 'period': 'nguyen'}]),
        isEmpty,
      );
    });

    test('a standalone target with no period is a problem', () {
      expect(run([{'type': 'person', 'id': 'p', 'era': ''}]).single,
          contains('has no period'));
    });

    test('an unknown period is a problem', () {
      expect(
        run([{'type': 'person', 'id': 'p', 'era': '', 'period': 'nope'}]).single,
        contains('unknown period'),
      );
    });

    test('an era and a period together is a problem', () {
      final problems = run([
        {'type': 'era', 'id': 'e', 'era': 'e', 'period': 'nguyen'},
      ]);
      expect(problems.single, contains('both an era and a period'));
    });
  });
}
