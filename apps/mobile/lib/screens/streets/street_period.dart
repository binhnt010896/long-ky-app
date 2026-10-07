import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../state/providers.dart';
import 'street_data.dart';

/// The street map's line color for each period (`periods.json` id).
///
/// Not the periods' own accents: those are dark (lightness 33–47 of 100), so
/// thin lines vanish on the map's dark ground, and several pairs are almost
/// identical (Nhà Trần / Kháng chiến chống Mỹ, Đổi Mới / Kỷ nguyên mới). These
/// keep each accent's hue family (within 24°), are lifted to a light, muted
/// range, and are nudged apart; the weakest pair is still clearly distinct.
/// Preview and method: docs/street-period-colors-plan.md. A period not listed
/// here (one added later) draws in [kStreetNeutral] until it gets a color.
const Map<String, Color> kStreetPeriodColors = <String, Color>{
  'hong-bang': Color(0xFF94D1B2),
  'nha-trieu': Color(0xFFC8B97E),
  'bac-thuoc': Color(0xFFD29A93),
  'ngo-dinh-tien-le': Color(0xFFDB6B74),
  'nha-ly': Color(0xFFDADA8B),
  'nha-tran': Color(0xFFDCAB89),
  'hau-le': Color(0xFF6ADC93),
  'phan-tranh': Color(0xFF7EB2C8),
  'tay-son': Color(0xFFDC6A8D),
  'nguyen': Color(0xFFDCA86A),
  'phap-thuoc': Color(0xFF7EC8C8),
  'khang-chien-chong-phap': Color(0xFFD97D6D),
  'khang-chien-chong-my': Color(0xFFDB8AA6),
  'thong-nhat': Color(0xFFDC926B),
  'chien-tranh-bien-gioi': Color(0xFFA9C87E),
  'doi-moi': Color(0xFFDCBE6A),
  'ky-nguyen-moi': Color(0xFFCDDC6A),
};

/// Streets with no known period, and the fallback for a period with no color.
/// The map's original resting gold.
final Color kStreetNeutral = Color.lerp(VSColors.gold, VSColors.lacquer, 0.4)!;

Color streetPeriodColor(String? periodId) =>
    (periodId == null ? null : kStreetPeriodColors[periodId]) ?? kStreetNeutral;

/// The period a street is drawn in: its first target that has one. An era
/// target takes its era's period; a standalone person or event takes the
/// `period` written on the target. Null when none resolves.
String? streetPeriodId(MappedStreet street, Map<String, String> eraPeriod) {
  for (final t in street.targets) {
    final p = t.era.isNotEmpty
        ? eraPeriod[t.era]
        : (t.period.isEmpty ? null : t.period);
    if (p != null) return p;
  }
  return null;
}

/// Which period each approved street is drawn in, and the periods that have
/// at least one street (in timeline order, with their street counts) — what
/// the map colors by and what the legend lists.
class StreetPeriods {
  const StreetPeriods({
    required this.byStreet,
    required this.periods,
    required this.counts,
  });

  /// Street id → period id (null = none known).
  final Map<String, String?> byStreet;

  /// Periods with streets, earliest first.
  final List<Period> periods;

  /// Period id → number of streets in it.
  final Map<String, int> counts;

  factory StreetPeriods.build({
    required Iterable<MappedStreet> streets,
    required Map<String, String> eraPeriod,
    required PeriodRegistry registry,
  }) {
    final byStreet = <String, String?>{};
    final counts = <String, int>{};
    for (final s in streets) {
      final p = streetPeriodId(s, eraPeriod);
      byStreet[s.id] = p;
      if (p != null) counts[p] = (counts[p] ?? 0) + 1;
    }
    return StreetPeriods(
      byStreet: byStreet,
      periods: [
        for (final p in registry.ordered)
          if ((counts[p.id] ?? 0) > 0) p,
      ],
      counts: counts,
    );
  }
}

/// The street map's periods, once the mapping, the eras and the period
/// registry are loaded. Null until then (the map draws neutral meanwhile).
final streetPeriodsProvider = FutureProvider<StreetPeriods?>((ref) async {
  final file = await ref.watch(streetMappingProvider.future);
  if (file == null) return null;
  final eras = await ref.watch(erasProvider.future);
  final registry = await ref.watch(periodsProvider.future);
  return StreetPeriods.build(
    streets: file.approved,
    eraPeriod: {
      for (final e in eras)
        if (e.period != null) e.slug: e.period!,
    },
    registry: registry,
  );
});
