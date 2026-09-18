import 'package:meta/meta.dart';

import 'asset_ref.dart';
import 'era.dart';
import 'json_util.dart';
import 'localized_text.dart';
import 'year.dart';

/// A dynasty / historical period (triều đại · thời kỳ) — the grouping level
/// above [Era]. Mirrors one entry of `content/periods.json`.
///
/// The dynasty hub scrolls periods vertically and their member eras
/// horizontally; an era declares its period via its `period` field, and the app
/// groups eras under the matching [Period.id].
@immutable
class Period {
  const Period({
    required this.id,
    required this.order,
    required this.title,
    required this.kicker,
    required this.yearRange,
    required this.accent,
    this.subtitle,
    this.cover,
  });

  final String id;

  /// Position in the vertical dynasty stack (0-based).
  final int order;
  final LocalizedText title;
  final LocalizedText kicker;

  /// Chronicle tagline for the dynasty. Optional.
  final LocalizedText? subtitle;
  final YearRange yearRange;

  /// Signature accent colour, `#RRGGBB`.
  final String accent;

  /// The dynasty's single signature cover image. Optional until art lands.
  final AssetRef? cover;

  factory Period.fromJson(Map<String, dynamic> json, [String at = 'period']) {
    final subtitle = json.objOrNull('subtitle', at: at);
    final cover = json.objOrNull('cover', at: at);
    return Period(
      id: json.str('id', at: at),
      order: json.integer('order', at: at),
      title: LocalizedText.fromJson(json.obj('title', at: at), '$at.title'),
      kicker: LocalizedText.fromJson(json.obj('kicker', at: at), '$at.kicker'),
      subtitle: subtitle == null
          ? null
          : LocalizedText.fromJson(subtitle, '$at.subtitle'),
      yearRange:
          YearRange.fromJson(json.obj('yearRange', at: at), '$at.yearRange'),
      accent: json.str('accent', at: at),
      cover: cover == null ? null : AssetRef.fromJson(cover, '$at.cover'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Period &&
      other.id == id &&
      other.order == order &&
      other.title == title &&
      other.kicker == kicker &&
      other.subtitle == subtitle &&
      other.yearRange == yearRange &&
      other.accent == accent &&
      other.cover == cover;

  @override
  int get hashCode =>
      Object.hash(id, order, title, kicker, subtitle, yearRange, accent, cover);
}

/// The ordered registry of periods, loaded from `content/periods.json`.
///
/// Eras group under these by their `period` id; [ordered] is the dynasty stack
/// top → bottom.
@immutable
class PeriodRegistry {
  const PeriodRegistry(this.byId, this.ordered);

  final Map<String, Period> byId;

  /// Periods sorted by [Period.order] — the vertical dynasty order.
  final List<Period> ordered;

  static const PeriodRegistry empty =
      PeriodRegistry(<String, Period>{}, <Period>[]);

  factory PeriodRegistry.fromJson(Map<String, dynamic> json) {
    final periods =
        json.list<Period>('periods', Period.fromJson, at: 'periods')
          ..sort((a, b) => a.order.compareTo(b.order));
    return PeriodRegistry(
      <String, Period>{for (final p in periods) p.id: p},
      List<Period>.unmodifiable(periods),
    );
  }

  Period? operator [](String id) => byId[id];
}

/// A dynasty paired with its member eras, in order — one row of the dynasty hub.
@immutable
class Dynasty {
  const Dynasty({required this.period, required this.eras});

  final Period period;

  /// The period's eras, sorted by [Era.order].
  final List<Era> eras;

  @override
  bool operator ==(Object other) =>
      other is Dynasty && other.period == period && _eraListEq(other.eras, eras);

  @override
  int get hashCode => Object.hash(period, Object.hashAll(eras));
}

bool _eraListEq(List<Era> a, List<Era> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
