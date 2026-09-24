import 'package:meta/meta.dart';

import '../citation.dart';
import '../localized_text.dart';

/// The five question shapes Câu đố can generate. Every question is built from
/// content already published in `content/` — no question text is hand-written,
/// so every answer traces back to a real event and its citation.
enum QuestionType { year, who, quote, order, era }

/// Where a generated question points back to, for the "Đọc sự kiện" link and
/// the visible citation shown after answering.
@immutable
class QuestionSource {
  const QuestionSource({
    required this.eraSlug,
    required this.eventId,
    required this.citation,
    required this.summary,
    this.note,
  });

  final String eraSlug;
  final String eventId;
  final Citation citation;

  /// The event's one-line summary, shown as feedback after answering.
  final LocalizedText summary;

  /// Supplementary feedback text — e.g. a pull-quote's attribution for a
  /// [QuestionType.quote] question. Null for the other types.
  final LocalizedText? note;
}

/// A question in the quiz. [McqQuestion] covers year/who/quote/era (one prompt,
/// four options, one correct index); [OrderQuestion] is the sequencing type.
@immutable
sealed class Question {
  const Question({required this.type});

  final QuestionType type;
}

/// A four-option multiple-choice question.
@immutable
final class McqQuestion extends Question {
  const McqQuestion({
    required super.type,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.source,
  });

  final LocalizedText prompt;

  /// Exactly 4 options, in the order shown; [correctIndex] names the right one.
  final List<LocalizedText> options;
  final int correctIndex;
  final QuestionSource source;
}

/// One event to place in chronological order.
@immutable
class OrderItem {
  const OrderItem({
    required this.title,
    required this.year,
    required this.eraSlug,
    required this.eventId,
  });

  final LocalizedText title;
  final int year;
  final String eraSlug;
  final String eventId;
}

/// "Put these in chronological order." [items] are pre-shuffled (not sorted);
/// [correctOrder] lists indices into [items] from earliest to latest.
@immutable
final class OrderQuestion extends Question {
  const OrderQuestion({
    required this.prompt,
    required this.items,
    required this.correctOrder,
  }) : super(type: QuestionType.order);

  final LocalizedText prompt;
  final List<OrderItem> items;
  final List<int> correctOrder;
}
