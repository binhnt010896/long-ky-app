import 'package:meta/meta.dart';

import 'json_util.dart';

/// The two languages the app carries. Vietnamese is canonical; English is a
/// toggle. There is deliberately no "system default" — `vi` is the ground truth.
enum Lang { vi, en }

/// A localized string: `vi` is required and canonical (with full diacritics),
/// `en` is optional. Resolution never silently drops diacritics — asking for
/// [Lang.en] when no English exists falls back to the Vietnamese canonical text.
@immutable
class LocalizedText {
  const LocalizedText({required this.vi, this.en});

  /// Canonical Vietnamese text. Always present.
  final String vi;

  /// Optional English translation.
  final String? en;

  /// The string for [lang], falling back to [vi] when [en] is absent.
  String resolve(Lang lang) => switch (lang) {
        Lang.vi => vi,
        Lang.en => en ?? vi,
      };

  /// True when an English toggle would actually change the text.
  bool get hasEnglish => en != null && en != vi;

  factory LocalizedText.fromJson(Map<String, dynamic> json, [String at = '']) {
    return LocalizedText(
      vi: json.str('vi', at: at.isEmpty ? null : at),
      en: json.strOrNull('en', at: at.isEmpty ? null : at),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LocalizedText && other.vi == vi && other.en == en;

  @override
  int get hashCode => Object.hash(vi, en);

  @override
  String toString() => 'LocalizedText(vi: "$vi"${en == null ? '' : ', en: "$en"'})';
}
