import 'dart:math';

import '../character.dart';
import '../era.dart';
import '../history_event.dart';
import '../localized_text.dart';
import 'question.dart';

/// The scope a quiz draws its questions from.
enum QuizMode {
  /// A fixed 5-question mix from the whole chronicle, deterministic per day
  /// (see [dailySeed]) — everyone gets the same five on a given date.
  daily,

  /// Questions from one period's eras only.
  byPeriod,

  /// Questions from the whole chronicle, freshly shuffled per [seed].
  random,

  /// Questions from one era only (the quiet "Thử sức kỷ nguyên này" link).
  byEra,
}

/// A seed that is the same for everyone on the same calendar day, for
/// [QuizMode.daily] — so "Câu đố hôm nay" is one shared quiz, not a random one
/// per launch.
int dailySeed(DateTime day) => day.year * 10000 + day.month * 100 + day.day;

typedef _EE = (Era, HistoryEvent);

String _yearLabel(int v) => v < 0 ? '${-v} TCN' : '$v';

LocalizedText _l(String vi, String en) => LocalizedText(vi: vi, en: en);

/// Builds [Question]s purely from already-published content — no question
/// text is hand-authored, so every answer traces back to a real event and
/// its citation. Deterministic for a given seed: the same (mode, seed, scope)
/// always yields the same questions in the same order.
///
/// Post-1975 political leaders (heads of the Party/State/Government) are
/// excluded from "who" questions — see [excludedLeaderIds] — per the app's
/// history-not-politics stance. Their events still surface in the other four
/// question types.
class QuizGenerator {
  const QuizGenerator(this.eras);

  final List<Era> eras;

  /// Tổng Bí thư / Chủ tịch nước / Thủ tướng figures from 1975 on. Their
  /// events remain fair game for every question type except "who".
  static const Set<String> excludedLeaderIds = <String>{
    'ton-duc-thang',
    'le-duan',
    'truong-chinh',
    'nguyen-van-linh',
    'vo-van-kiet',
    'do-muoi',
    'le-duc-anh',
    'le-kha-phieu',
    'tran-duc-luong',
    'phan-van-khai',
    'nong-duc-manh',
    'nguyen-tan-dung',
    'nguyen-phu-trong',
    'to-lam',
    'pham-minh-chinh',
    'luong-cuong',
    'pham-van-dong',
  };

  /// Generate up to [count] questions. May return fewer than [count] if the
  /// scope is too thin (e.g. a short era) to support that many without
  /// repeating a source event. Never throws on any real content shape —
  /// a type with no eligible candidates in-scope is simply left out.
  List<Question> generate({
    required QuizMode mode,
    required int seed,
    String? periodId,
    String? eraSlug,
    int count = 10,
  }) {
    final rng = Random(seed);
    final scope = _scopeEvents(mode, periodId, eraSlug);
    if (scope.isEmpty) return const <Question>[];
    final global = _allEvents();

    final queues = <QuestionType, List<Question>>{
      QuestionType.year: _buildYear(scope, global, rng),
      QuestionType.who: _buildWho(scope, rng),
      QuestionType.quote: _buildQuote(scope, global, rng),
      QuestionType.era: _buildEra(scope, rng),
    };
    for (final q in queues.values) {
      q.shuffle(rng);
    }
    final cursors = <QuestionType, int>{
      for (final t in queues.keys) t: 0,
    };
    final orderPool = List<_EE>.of(scope);

    final typeOrder = QuestionType.values.toList()..shuffle(rng);
    final result = <Question>[];
    final used = <String>{};

    var progressed = true;
    while (result.length < count && progressed) {
      progressed = false;
      for (final t in typeOrder) {
        if (result.length >= count) break;
        if (t == QuestionType.order) {
          final oq = _tryBuildOrder(orderPool, rng, used);
          if (oq != null) {
            result.add(oq);
            used.addAll(oq.items.map((i) => i.eventId));
            progressed = true;
          }
          continue;
        }
        final list = queues[t]!;
        var c = cursors[t]!;
        while (c < list.length) {
          final q = list[c];
          c++;
          final id = (q as McqQuestion).source.eventId;
          if (used.contains(id)) continue;
          used.add(id);
          result.add(q);
          progressed = true;
          break;
        }
        cursors[t] = c;
      }
    }
    return result;
  }

  // ---- scope -----------------------------------------------------------

  List<_EE> _scopeEvents(QuizMode mode, String? periodId, String? eraSlug) {
    Iterable<Era> selected;
    switch (mode) {
      case QuizMode.byEra:
        selected = eras.where((e) => e.slug == eraSlug);
      case QuizMode.byPeriod:
        selected = eras.where((e) => e.period == periodId);
      case QuizMode.daily:
      case QuizMode.random:
        selected = eras;
    }
    return <_EE>[
      for (final era in selected)
        for (final event in era.events) (era, event),
    ];
  }

  List<_EE> _allEvents() => <_EE>[
        for (final era in eras)
          for (final event in era.events) (era, event),
      ];

  // ---- Q1: year ----------------------------------------------------------

  List<Question> _buildYear(List<_EE> scope, List<_EE> global, Random rng) {
    bool eligible(_EE ee) =>
        ee.$2.kind == EventKind.historical &&
        ee.$2.year.isDated &&
        !ee.$2.year.approximate;
    final candidates = scope.where(eligible).toList();
    final preferredYears =
        candidates.map((ee) => ee.$2.year.value!).toSet();
    final globalYears = global
        .where(eligible)
        .map((ee) => ee.$2.year.value!)
        .toSet();

    final out = <Question>[];
    for (final ee in candidates) {
      final correct = ee.$2.year.value!;
      final distractors = _pickFarValues(
        correct: correct,
        preferred: preferredYears,
        fallback: globalYears,
        rng: rng,
        need: 3,
        minGap: 5,
      );
      if (distractors.length < 3) continue;
      final optionYears = <int>[...distractors, correct]..shuffle(rng);
      out.add(McqQuestion(
        type: QuestionType.year,
        prompt: _l(
          '"${ee.$2.title.vi}" diễn ra năm nào?',
          'When did "${ee.$2.title.en ?? ee.$2.title.vi}" happen?',
        ),
        options: <LocalizedText>[
          for (final y in optionYears) _l(_yearLabel(y), _yearLabel(y)),
        ],
        correctIndex: optionYears.indexOf(correct),
        source: _sourceOf(ee),
      ));
    }
    return out;
  }

  /// Picks [need] values at least [minGap] apart from [correct] and from
  /// each other, preferring [preferred] and widening to [fallback] if that
  /// pool can't supply enough.
  List<int> _pickFarValues({
    required int correct,
    required Set<int> preferred,
    required Set<int> fallback,
    required Random rng,
    required int need,
    required int minGap,
  }) {
    final chosen = <int>{};
    bool farEnough(int y) =>
        (y - correct).abs() >= minGap &&
        chosen.every((c) => (c - y).abs() >= minGap);
    for (final pool in <Set<int>>[preferred, fallback]) {
      final shuffled = pool.toList()..shuffle(rng);
      for (final y in shuffled) {
        if (chosen.length >= need) break;
        if (y == correct) continue;
        if (farEnough(y)) chosen.add(y);
      }
      if (chosen.length >= need) break;
    }
    return chosen.toList();
  }

  // ---- Q2: who -------------------------------------------------------

  List<Question> _buildWho(List<_EE> scope, Random rng) {
    final scopeFigures = <String, Character>{};
    for (final ee in scope) {
      for (final c in ee.$1.characters) {
        if (!excludedLeaderIds.contains(c.id)) scopeFigures[c.id] = c;
      }
    }
    final globalFigures = <String, Character>{};
    for (final era in eras) {
      for (final c in era.characters) {
        if (!excludedLeaderIds.contains(c.id)) globalFigures[c.id] = c;
      }
    }

    final out = <Question>[];
    for (final ee in scope) {
      final figs = ee.$1
          .charactersFor(ee.$2)
          .where((c) => !excludedLeaderIds.contains(c.id))
          .toList();
      if (figs.isEmpty) continue;
      final correct = figs.first;
      final distractors = _pickFarObjects<Character>(
        correct: correct,
        preferred: scopeFigures.values.where((c) => c.id != correct.id),
        fallback: globalFigures.values.where((c) => c.id != correct.id),
        idOf: (c) => c.id,
        rng: rng,
        need: 3,
      );
      if (distractors.length < 3) continue;
      final options = <Character>[...distractors, correct]..shuffle(rng);
      out.add(McqQuestion(
        type: QuestionType.who,
        prompt: _l(
          'Nhân vật nào gắn với "${ee.$2.title.vi}"?',
          'Which figure is tied to "${ee.$2.title.en ?? ee.$2.title.vi}"?',
        ),
        options: <LocalizedText>[for (final c in options) c.name],
        correctIndex: options.indexWhere((c) => c.id == correct.id),
        source: _sourceOf(ee),
      ));
    }
    return out;
  }

  // ---- Q3: quote → event -------------------------------------------------

  List<Question> _buildQuote(List<_EE> scope, List<_EE> global, Random rng) {
    final out = <Question>[];
    for (final ee in scope) {
      final quote = ee.$2.pullQuote;
      if (quote == null) continue;
      final sameEra = <_EE>[
        for (final other in ee.$1.events)
          if (other.id != ee.$2.id) (ee.$1, other),
      ];
      final distractors = _pickFarObjects<_EE>(
        correct: ee,
        preferred: sameEra,
        fallback: global.where((g) => g.$2.id != ee.$2.id),
        idOf: (e) => e.$2.id,
        rng: rng,
        need: 3,
      );
      if (distractors.length < 3) continue;
      final options = <_EE>[...distractors, ee]..shuffle(rng);
      out.add(McqQuestion(
        type: QuestionType.quote,
        prompt: _l(
          'Câu "${quote.text.vi}" gắn với sự kiện nào?',
          'Which event does the quote "${quote.text.en ?? quote.text.vi}" belong to?',
        ),
        options: <LocalizedText>[for (final o in options) o.$2.title],
        correctIndex: options.indexWhere((o) => o.$2.id == ee.$2.id),
        source: _sourceOf(ee, note: quote.attribution),
      ));
    }
    return out;
  }

  // ---- Q4: order ----------------------------------------------------------

  OrderQuestion? _tryBuildOrder(List<_EE> pool, Random rng, Set<String> used) {
    final eligible = pool
        .where((ee) =>
            ee.$2.kind == EventKind.historical &&
            ee.$2.year.isDated &&
            !ee.$2.year.approximate &&
            !used.contains(ee.$2.id))
        .toList();
    if (eligible.length < 4) return null;
    for (var attempt = 0; attempt < 40; attempt++) {
      eligible.shuffle(rng);
      final picked = <_EE>[];
      for (final ee in eligible) {
        if (picked.length == 4) break;
        final y = ee.$2.year.value!;
        if (picked.every((p) => (p.$2.year.value! - y).abs() >= 3)) {
          picked.add(ee);
        }
      }
      if (picked.length == 4) {
        final order = List<int>.generate(4, (i) => i)
          ..sort((a, b) =>
              picked[a].$2.year.value!.compareTo(picked[b].$2.year.value!));
        return OrderQuestion(
          prompt: _l('Sắp xếp theo thứ tự thời gian',
              'Put these in chronological order'),
          items: <OrderItem>[
            for (final ee in picked)
              OrderItem(
                title: ee.$2.title,
                year: ee.$2.year.value!,
                eraSlug: ee.$1.slug,
                eventId: ee.$2.id,
              ),
          ],
          correctOrder: order,
        );
      }
    }
    return null;
  }

  // ---- Q5: era --------------------------------------------------------

  List<Question> _buildEra(List<_EE> scope, Random rng) {
    final out = <Question>[];
    for (final ee in scope) {
      final era = ee.$1;
      final samePeriod =
          eras.where((e) => e.slug != era.slug && e.period == era.period);
      final others = eras.where((e) => e.slug != era.slug);
      final distractors = _pickFarObjects<Era>(
        correct: era,
        preferred: samePeriod,
        fallback: others,
        idOf: (e) => e.slug,
        rng: rng,
        need: 3,
      );
      if (distractors.length < 3) continue;
      final options = <Era>[...distractors, era]..shuffle(rng);
      out.add(McqQuestion(
        type: QuestionType.era,
        prompt: _l(
          '"${ee.$2.title.vi}" thuộc kỷ nguyên nào?',
          'Which era does "${ee.$2.title.en ?? ee.$2.title.vi}" belong to?',
        ),
        options: <LocalizedText>[for (final e in options) e.title],
        correctIndex: options.indexWhere((e) => e.slug == era.slug),
        source: _sourceOf(ee),
      ));
    }
    return out;
  }

  // ---- shared helpers -----------------------------------------------------

  QuestionSource _sourceOf(_EE ee, {LocalizedText? note}) => QuestionSource(
        eraSlug: ee.$1.slug,
        eventId: ee.$2.id,
        citation: ee.$2.citation,
        summary: ee.$2.summary,
        note: note,
      );

  /// Generic distractor picker: [need] distinct objects (by [idOf]), never
  /// the [correct] one, drawn from [preferred] first and [fallback] if short.
  List<T> _pickFarObjects<T>({
    required T correct,
    required Iterable<T> preferred,
    required Iterable<T> fallback,
    required String Function(T) idOf,
    required Random rng,
    required int need,
  }) {
    final chosenIds = <String>{};
    final chosen = <T>[];
    final correctId = idOf(correct);
    for (final pool in <Iterable<T>>[preferred, fallback]) {
      final shuffled = pool.toList()..shuffle(rng);
      for (final item in shuffled) {
        if (chosen.length >= need) break;
        final id = idOf(item);
        if (id == correctId || chosenIds.contains(id)) continue;
        chosenIds.add(id);
        chosen.add(item);
      }
      if (chosen.length >= need) break;
    }
    return chosen;
  }
}
