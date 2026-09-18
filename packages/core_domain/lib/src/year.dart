import 'package:meta/meta.dart';

import 'json_util.dart';
import 'localized_text.dart';

/// A point in time as content expresses it: a human label plus an optional
/// numeric value for sorting/placement. Legendary events carry a null [value]
/// ("Huyền sử", "Truyền thuyết") — they have no fixed date.
@immutable
class YearRef {
  const YearRef({
    required this.display,
    this.value,
    this.approximate = false,
  });

  /// Label as shown, e.g. "≈ 2879 TCN" or "Huyền sử".
  final LocalizedText display;

  /// Numeric year for ordering/scrubbing. Negative = BCE (TCN). Null for legend.
  final int? value;

  /// True when the date is circa (≈).
  final bool approximate;

  /// Whether this event can be placed on a numeric timeline.
  bool get isDated => value != null;

  factory YearRef.fromJson(Map<String, dynamic> json, [String at = 'year']) {
    return YearRef(
      display: LocalizedText.fromJson(json.obj('display', at: at), '$at.display'),
      value: json.integerOrNull('value', at: at),
      approximate: json.boolOr('approximate', false, at: at),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is YearRef &&
      other.display == display &&
      other.value == value &&
      other.approximate == approximate;

  @override
  int get hashCode => Object.hash(display, value, approximate);
}

/// The span an era covers.
@immutable
class YearRange {
  const YearRange({required this.display, this.startYear, this.endYear});

  final LocalizedText display;
  final int? startYear;
  final int? endYear;

  factory YearRange.fromJson(Map<String, dynamic> json,
      [String at = 'yearRange']) {
    return YearRange(
      display: LocalizedText.fromJson(json.obj('display', at: at), '$at.display'),
      startYear: json.integerOrNull('startYear', at: at),
      endYear: json.integerOrNull('endYear', at: at),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is YearRange &&
      other.display == display &&
      other.startYear == startYear &&
      other.endYear == endYear;

  @override
  int get hashCode => Object.hash(display, startYear, endYear);
}
