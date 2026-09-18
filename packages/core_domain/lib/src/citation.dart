import 'package:meta/meta.dart';

import 'json_util.dart';
import 'localized_text.dart';

/// A visible source citation. Rendered on every event — provenance is a feature
/// of Việt Sử, not fine print.
@immutable
class Citation {
  const Citation({
    required this.work,
    this.section,
    this.author,
    this.url,
    this.note,
  });

  /// Title of the chronicle/work, e.g. "Đại Việt sử ký toàn thư".
  final String work;

  /// Locus within the work, e.g. "Ngoại kỷ · Quyển 1".
  final LocalizedText? section;

  final String? author;
  final String? url;
  final LocalizedText? note;

  factory Citation.fromJson(Map<String, dynamic> json, [String at = 'citation']) {
    final section = json.objOrNull('section', at: at);
    final note = json.objOrNull('note', at: at);
    return Citation(
      work: json.str('work', at: at),
      section: section == null
          ? null
          : LocalizedText.fromJson(section, '$at.section'),
      author: json.strOrNull('author', at: at),
      url: json.strOrNull('url', at: at),
      note: note == null ? null : LocalizedText.fromJson(note, '$at.note'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Citation &&
      other.work == work &&
      other.section == section &&
      other.author == author &&
      other.url == url &&
      other.note == note;

  @override
  int get hashCode => Object.hash(work, section, author, url, note);
}
