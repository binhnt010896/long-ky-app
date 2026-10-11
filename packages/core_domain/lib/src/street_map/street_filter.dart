import 'package:meta/meta.dart';

import '../era.dart';
import '../localized_text.dart';
import '../period.dart';
import 'street_map.dart';

/// One cell of the street map's filter: a period, and an era within it. An
/// empty [era] is the period's "other figures and events" row — standalone
/// targets that carry a period but no era. An empty [period] is the catch-all
/// for a target whose period is unknown.
@immutable
class StreetBucket {
  const StreetBucket(this.period, this.era);

  final String period;
  final String era;

  @override
  bool operator ==(Object other) =>
      other is StreetBucket && other.period == period && other.era == era;

  @override
  int get hashCode => Object.hash(period, era);
}

/// The buckets a street sits in — one per target, de-duplicated. A target with
/// an era sits under that era (and the era's period); a standalone one sits
/// under its own `period`; one with neither sits in the catch-all.
Set<StreetBucket> bucketsOf(MappedStreet s, Map<String, String> periodOfEra) {
  return <StreetBucket>{
    for (final t in s.targets)
      if (t.era.isNotEmpty)
        StreetBucket(periodOfEra[t.era] ?? '', t.era)
      else
        StreetBucket(t.period, ''),
  };
}

/// Ids of the streets that stay on the map when [hidden] buckets are off. A
/// street stays while any one of its targets is still selected, so a street
/// named for two figures is not lost by hiding just one of their eras.
/// An empty [hidden] means nothing is filtered.
Set<String> visibleStreetIds(
  Iterable<MappedStreet> streets,
  Set<StreetBucket> hidden,
  Map<String, String> periodOfEra,
) {
  return <String>{
    for (final s in streets)
      if (hidden.isEmpty ||
          bucketsOf(s, periodOfEra).any((b) => !hidden.contains(b)))
        s.id,
  };
}

/// How many streets sit in each bucket (a street counts once per bucket).
Map<StreetBucket, int> countBuckets(
  Iterable<MappedStreet> streets,
  Map<String, String> periodOfEra,
) {
  final counts = <StreetBucket, int>{};
  for (final s in streets) {
    for (final b in bucketsOf(s, periodOfEra)) {
      counts[b] = (counts[b] ?? 0) + 1;
    }
  }
  return counts;
}

@immutable
class StreetFilterRow {
  const StreetFilterRow(this.bucket, this.label, this.count);
  final StreetBucket bucket;
  final LocalizedText label;
  final int count;
}

@immutable
class StreetFilterGroup {
  const StreetFilterGroup(this.period, this.title, this.range, this.rows);

  final String period;
  final LocalizedText title;
  final LocalizedText? range;
  final List<StreetFilterRow> rows;

  int get count => rows.fold(0, (n, r) => n + r.count);
}

const LocalizedText _otherRow = LocalizedText(
  vi: 'Nhân vật và sự kiện khác',
  en: 'Other figures and events',
);
const LocalizedText _otherGroup = LocalizedText(vi: 'Khác', en: 'Other');

/// The filter sheet's content: periods in order, each with its eras, listing
/// only what has at least one street. Unknown periods/eras land in a final
/// "Other" group, so every street is reachable by some row.
List<StreetFilterGroup> buildFilterGroups({
  required PeriodRegistry periods,
  required List<Era> eras,
  required Map<StreetBucket, int> counts,
}) {
  final erasByPeriod = <String, List<Era>>{};
  for (final e in eras) {
    (erasByPeriod[e.period ?? ''] ??= <Era>[]).add(e);
  }
  for (final list in erasByPeriod.values) {
    list.sort((a, b) => a.order.compareTo(b.order));
  }

  final used = <StreetBucket>{};
  StreetFilterRow? row(StreetBucket b, LocalizedText label) {
    final n = counts[b] ?? 0;
    if (n == 0) return null;
    used.add(b);
    return StreetFilterRow(b, label, n);
  }

  final groups = <StreetFilterGroup>[];
  for (final p in periods.ordered) {
    final rows = <StreetFilterRow>[
      for (final e in erasByPeriod[p.id] ?? const <Era>[])
        ?row(StreetBucket(p.id, e.slug), e.title),
      ?row(StreetBucket(p.id, ''), _otherRow),
    ];
    if (rows.isNotEmpty) {
      groups.add(StreetFilterGroup(p.id, p.title, p.yearRange.display, rows));
    }
  }

  // Whatever no period above accounted for (an era with no or an unknown
  // period, a standalone target with no period).
  final bySlug = {for (final e in eras) e.slug: e};
  final rest = <StreetFilterRow>[
    for (final e in counts.entries)
      if (!used.contains(e.key))
        StreetFilterRow(
          e.key,
          bySlug[e.key.era]?.title ?? _otherRow,
          e.value,
        ),
  ];
  if (rest.isNotEmpty) {
    groups.add(StreetFilterGroup('', _otherGroup, null, rest));
  }
  return groups;
}
