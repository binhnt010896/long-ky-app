import 'package:meta/meta.dart';

import 'asset_ref.dart';
import 'citation.dart';
import 'json_util.dart';
import 'localized_text.dart';
import 'year.dart';

/// Historiographic status of an event — legend, semi-historical, or historical.
/// Drives how strongly the UI can assert the claim.
enum EventKind { legend, semiHistorical, historical }

/// The italic chronicle pull-quote that recurs through the app.
@immutable
class PullQuote {
  const PullQuote({required this.text, this.attribution});

  final LocalizedText text;
  final LocalizedText? attribution;

  factory PullQuote.fromJson(Map<String, dynamic> json,
      [String at = 'pullQuote']) {
    final attribution = json.objOrNull('attribution', at: at);
    return PullQuote(
      text: LocalizedText.fromJson(json.obj('text', at: at), '$at.text'),
      attribution: attribution == null
          ? null
          : LocalizedText.fromJson(attribution, '$at.attribution'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PullQuote &&
      other.text == text &&
      other.attribution == attribution;

  @override
  int get hashCode => Object.hash(text, attribution);
}

/// A single event on an era's timeline.
///
/// Every event carries a [citation]; the schema requires it and the UI renders
/// it visibly. [order] is the authoritative sequence within the era; [year]
/// carries the numeric value (may be null for legend) used by the global
/// timeline scrubber.
@immutable
class HistoryEvent {
  const HistoryEvent({
    required this.id,
    required this.order,
    required this.kind,
    required this.year,
    required this.title,
    required this.summary,
    required this.citation,
    this.slug,
    this.body,
    this.details,
    this.pullQuote,
    this.hero,
    this.figureIds = const <String>[],
    this.relatedEventIds = const <String>[],
  });

  final String id;
  final String? slug;
  final int order;
  final EventKind kind;
  final YearRef year;
  final LocalizedText title;

  /// One-line timeline subtitle.
  final LocalizedText summary;

  /// Long-form detail body.
  final LocalizedText? body;

  /// Fuller account revealed under "read more".
  final LocalizedText? details;
  final PullQuote? pullQuote;
  final AssetRef? hero;
  final Citation citation;

  /// Ids into the era's character roster of figures appearing in this event.
  final List<String> figureIds;

  /// Ids of related events within the era.
  final List<String> relatedEventIds;

  factory HistoryEvent.fromJson(Map<String, dynamic> json,
      [String at = 'event']) {
    final body = json.objOrNull('body', at: at);
    final details = json.objOrNull('details', at: at);
    final pullQuote = json.objOrNull('pullQuote', at: at);
    final hero = json.objOrNull('hero', at: at);
    return HistoryEvent(
      id: json.str('id', at: at),
      slug: json.strOrNull('slug', at: at),
      order: json.integer('order', at: at),
      kind: _eventKind(json.str('kind', at: at), at),
      year: YearRef.fromJson(json.obj('year', at: at), '$at.year'),
      title: LocalizedText.fromJson(json.obj('title', at: at), '$at.title'),
      summary:
          LocalizedText.fromJson(json.obj('summary', at: at), '$at.summary'),
      body: body == null ? null : LocalizedText.fromJson(body, '$at.body'),
      details:
          details == null ? null : LocalizedText.fromJson(details, '$at.details'),
      pullQuote:
          pullQuote == null ? null : PullQuote.fromJson(pullQuote, '$at.pullQuote'),
      hero: hero == null ? null : AssetRef.fromJson(hero, '$at.hero'),
      citation:
          Citation.fromJson(json.obj('citation', at: at), '$at.citation'),
      figureIds: json.stringList('figureIds', at: at),
      relatedEventIds: json.stringList('relatedEventIds', at: at),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HistoryEvent &&
      other.id == id &&
      other.slug == slug &&
      other.order == order &&
      other.kind == kind &&
      other.year == year &&
      other.title == title &&
      other.summary == summary &&
      other.body == body &&
      other.details == details &&
      other.pullQuote == pullQuote &&
      other.hero == hero &&
      other.citation == citation &&
      _stringListEq(other.figureIds, figureIds) &&
      _stringListEq(other.relatedEventIds, relatedEventIds);

  @override
  int get hashCode => Object.hash(
        id,
        slug,
        order,
        kind,
        year,
        title,
        summary,
        body,
        details,
        pullQuote,
        hero,
        citation,
        Object.hashAll(figureIds),
        Object.hashAll(relatedEventIds),
      );
}

bool _stringListEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

EventKind _eventKind(String raw, String at) => switch (raw) {
      'legend' => EventKind.legend,
      'semi-historical' => EventKind.semiHistorical,
      'historical' => EventKind.historical,
      _ => throw ContentFormatException('unknown event kind `$raw`', path: at),
    };
