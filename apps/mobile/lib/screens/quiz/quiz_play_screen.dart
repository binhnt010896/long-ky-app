import 'dart:math';

import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../state/providers.dart';
import '../../state/quiz_store.dart';
import '../../widgets/circle_icon_button.dart';
import '../../widgets/lang_toggle.dart';

int _countFor(QuizMode mode) => switch (mode) {
      QuizMode.daily => 5,
      QuizMode.byEra => 5,
      QuizMode.byPeriod => 10,
      QuizMode.random => 10,
    };

String _modeKeyFor(QuizMode mode, {String? periodId, String? eraSlug}) =>
    switch (mode) {
      QuizMode.daily => QuizModeKey.daily,
      QuizMode.random => QuizModeKey.random,
      QuizMode.byPeriod => QuizModeKey.period(periodId!),
      QuizMode.byEra => QuizModeKey.era(eraSlug!),
    };

/// Plays one quiz: generates its questions once from [mode]/[seed]/scope,
/// walks through them one at a time with instant right/wrong feedback and a
/// visible citation, then shows the score inline (no separate route — the
/// question list, answers and score are ephemeral session state, not
/// something worth a URL).
class QuizPlayScreen extends ConsumerStatefulWidget {
  const QuizPlayScreen({
    required this.mode,
    required this.seed,
    this.periodId,
    this.eraSlug,
    super.key,
  });

  final QuizMode mode;
  final int seed;
  final String? periodId;
  final String? eraSlug;

  @override
  ConsumerState<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends ConsumerState<QuizPlayScreen> {
  List<Question>? _questions;
  Object? _error;

  int _index = 0;
  int _score = 0;
  bool _answered = false;
  int? _selectedMcqIndex;
  final List<int> _tappedOrder = <int>[];
  final List<Question> _missed = <Question>[];
  bool _finished = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final eras = await ref.read(erasProvider.future);
      final generator = QuizGenerator(eras);
      final questions = generator.generate(
        mode: widget.mode,
        seed: widget.seed,
        periodId: widget.periodId,
        eraSlug: widget.eraSlug,
        count: _countFor(widget.mode),
      );
      if (!mounted) return;
      setState(() => _questions = questions);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  void _answerMcq(McqQuestion q, int i) {
    if (_answered) return;
    setState(() {
      _answered = true;
      _selectedMcqIndex = i;
      if (i == q.correctIndex) {
        _score++;
      } else {
        _missed.add(q);
      }
    });
  }

  void _tapOrderItem(OrderQuestion q, int itemIndex) {
    if (_answered || _tappedOrder.contains(itemIndex)) return;
    setState(() {
      _tappedOrder.add(itemIndex);
      if (_tappedOrder.length == q.items.length) {
        _answered = true;
        final correct = _listEquals(_tappedOrder, q.correctOrder);
        if (correct) {
          _score++;
        } else {
          _missed.add(q);
        }
      }
    });
  }

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _next() {
    final questions = _questions!;
    if (_index + 1 >= questions.length) {
      setState(() => _finished = true);
      _saveResult();
      return;
    }
    setState(() {
      _index++;
      _answered = false;
      _selectedMcqIndex = null;
      _tappedOrder.clear();
    });
  }

  Future<void> _saveResult() async {
    if (_saved) return;
    _saved = true;
    final modeKey = _modeKeyFor(widget.mode,
        periodId: widget.periodId, eraSlug: widget.eraSlug);
    await ref.read(quizStoreProvider).recordResult(
          modeKey: modeKey,
          score: _score,
          total: _questions!.length,
          dailyOn: widget.mode == QuizMode.daily ? DateTime.now() : null,
        );
    ref.invalidate(quizProgressProvider);
  }

  void _playAgain() {
    final seed = widget.mode == QuizMode.daily
        ? widget.seed
        : Random().nextInt(1 << 31);
    final qp = <String, String>{
      'mode': switch (widget.mode) {
        QuizMode.daily => 'daily',
        QuizMode.random => 'random',
        QuizMode.byPeriod => 'period',
        QuizMode.byEra => 'era',
      },
      'seed': '$seed',
      if (widget.periodId != null) 'period': widget.periodId!,
      if (widget.eraSlug != null) 'era': widget.eraSlug!,
    };
    final query = qp.entries.map((e) => '${e.key}=${e.value}').join('&');
    context.pushReplacement('/sanh/cau-do/choi?$query');
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final en = lang == Lang.en;

    return Scaffold(
      backgroundColor: VSColors.lacquer,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: VSSpacing.xl, vertical: VSSpacing.sm),
              child: Row(
                children: <Widget>[
                  CircleIconButton(
                    icon: Icons.close,
                    onTap: () => context.canPop()
                        ? context.pop()
                        : context.go('/sanh/cau-do'),
                  ),
                  const Spacer(),
                  if (_questions != null && !_finished)
                    Text(
                      en
                          ? 'Question ${_index + 1}/${_questions!.length}'
                          : 'Câu ${_index + 1}/${_questions!.length}',
                      style: VSType.caption.copyWith(color: VSColors.inkMuted),
                    ),
                  const Spacer(),
                  const LangToggle(),
                ],
              ),
            ),
            if (_questions != null && !_finished)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: VSSpacing.xl),
                child: _ProgressBar(
                  fraction: (_index + 1) / _questions!.length,
                ),
              ),
            Expanded(child: _body(en)),
          ],
        ),
      ),
    );
  }

  Widget _body(bool en) {
    if (_error != null) {
      return Center(
        child: Text(
          en ? 'Couldn\'t load the quiz.' : 'Không tải được câu đố.',
          style: VSType.bodySmall,
        ),
      );
    }
    final questions = _questions;
    if (questions == null) {
      return const Center(
        child: CircularProgressIndicator(color: VSColors.gold),
      );
    }
    if (questions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(VSSpacing.xl),
          child: Text(
            en
                ? 'Not enough content here yet for a quiz.'
                : 'Chưa đủ nội dung để tạo câu đố ở đây.',
            style: VSType.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_finished) {
      return _ResultView(
        score: _score,
        total: questions.length,
        missed: _missed,
        en: en,
        onPlayAgain: _playAgain,
        onClose: () => context.go('/sanh/cau-do'),
      );
    }
    final q = questions[_index];
    return switch (q) {
      McqQuestion() => _McqView(
          key: ValueKey<String>('mcq-$_index'),
          question: q,
          selected: _selectedMcqIndex,
          answered: _answered,
          en: en,
          onSelect: (i) => _answerMcq(q, i),
          onNext: _next,
        ),
      OrderQuestion() => _OrderView(
          key: ValueKey<String>('order-$_index'),
          question: q,
          tappedOrder: _tappedOrder,
          answered: _answered,
          en: en,
          onTapItem: (i) => _tapOrderItem(q, i),
          onNext: _next,
        ),
    };
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction});
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      margin: const EdgeInsets.only(bottom: VSSpacing.md),
      decoration: BoxDecoration(
        color: VSColors.goldBorder,
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: fraction.clamp(0.0, 1.0),
        child: Container(
          decoration: const BoxDecoration(
            gradient: VSColors.goldSheen,
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
        ),
      ),
    );
  }
}

class _McqView extends StatelessWidget {
  const _McqView({
    required this.question,
    required this.selected,
    required this.answered,
    required this.en,
    required this.onSelect,
    required this.onNext,
    super.key,
  });

  final McqQuestion question;
  final int? selected;
  final bool answered;
  final bool en;
  final ValueChanged<int> onSelect;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final lang = en ? Lang.en : Lang.vi;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          VSSpacing.xl, VSSpacing.md, VSSpacing.xl, VSSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(question.prompt.resolve(lang), style: VSType.headline),
          const SizedBox(height: VSSpacing.xl),
          for (var i = 0; i < question.options.length; i++) ...<Widget>[
            _OptionTile(
              key: ValueKey<int>(i),
              label: question.options[i].resolve(lang),
              state: !answered
                  ? _OptionState.idle
                  : i == question.correctIndex
                      ? _OptionState.correct
                      : i == selected
                          ? _OptionState.wrong
                          : _OptionState.faded,
              onTap: () => onSelect(i),
            ),
            const SizedBox(height: VSSpacing.sm),
          ],
          if (answered) ...<Widget>[
            const SizedBox(height: VSSpacing.md),
            _FeedbackPanel(source: question.source, en: en),
            const SizedBox(height: VSSpacing.xl),
            _NextButton(en: en, onTap: onNext),
          ],
        ],
      ),
    );
  }
}

enum _OptionState { idle, correct, wrong, faded }

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.state,
    required this.onTap,
    super.key,
  });

  final String label;
  final _OptionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color border;
    final Color? fill;
    final Color textColor;
    switch (state) {
      case _OptionState.idle:
        border = VSColors.goldBorder;
        fill = null;
        textColor = VSColors.inkPrimary;
      case _OptionState.correct:
        border = VSColors.goldBright;
        fill = VSColors.gold.withValues(alpha: 0.18);
        textColor = VSColors.goldBright;
      case _OptionState.wrong:
        border = const Color(0x99C0524A);
        fill = const Color(0x33C0524A);
        textColor = VSColors.inkPrimary;
      case _OptionState.faded:
        border = VSColors.goldBorder;
        fill = null;
        textColor = VSColors.inkFaint;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: VSSpacing.md, vertical: VSSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: border),
          borderRadius: VSRadii.cardAll,
          color: fill,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
                child:
                    Text(label, style: VSType.body.copyWith(color: textColor))),
            if (state == _OptionState.correct)
              const Icon(Icons.check_circle, size: 18, color: VSColors.goldBright),
            if (state == _OptionState.wrong)
              const Icon(Icons.cancel, size: 18, color: Color(0xFFC0524A)),
          ],
        ),
      ),
    );
  }
}

class _FeedbackPanel extends StatelessWidget {
  const _FeedbackPanel({required this.source, required this.en});

  final QuestionSource source;
  final bool en;

  @override
  Widget build(BuildContext context) {
    final lang = en ? Lang.en : Lang.vi;
    final section = source.citation.section?.resolve(lang);
    final meta = <String>[
      if (section != null) section,
      if (source.citation.author != null) source.citation.author!,
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(VSSpacing.md),
      decoration: BoxDecoration(
        color: VSColors.goldWash,
        borderRadius: VSRadii.citationAll,
        border: Border.all(color: VSColors.goldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(source.summary.resolve(lang), style: VSType.bodySmall),
          if (source.note != null) ...<Widget>[
            const SizedBox(height: VSSpacing.xs),
            Text(
              '— ${source.note!.resolve(lang)}',
              style: VSType.caption.copyWith(
                  color: VSColors.inkMuted, fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: VSSpacing.sm),
          Text(
            <String>[source.citation.work, if (meta.isNotEmpty) meta]
                .join(' · '),
            style: VSType.caption.copyWith(color: VSColors.goldBright),
          ),
          const SizedBox(height: VSSpacing.sm),
          GestureDetector(
            onTap: () => GoRouter.of(context)
                .push('/era/${source.eraSlug}/event/${source.eventId}'),
            child: Text(
              en ? 'Read the event ›' : 'Đọc sự kiện ›',
              style: VSType.label.copyWith(color: VSColors.goldBright),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({required this.en, required this.onTap});
  final bool en;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              VSColors.goldBright.withValues(alpha: 0.16),
              VSColors.gold.withValues(alpha: 0.10),
            ],
          ),
          borderRadius: VSRadii.pillAll,
          border: Border.all(color: VSColors.gold.withValues(alpha: 0.6)),
        ),
        child: Text(
          en ? 'Next ›' : 'Tiếp theo ›',
          style: VSType.label.copyWith(color: VSColors.inkPrimary),
        ),
      ),
    );
  }
}

class _OrderView extends StatelessWidget {
  const _OrderView({
    required this.question,
    required this.tappedOrder,
    required this.answered,
    required this.en,
    required this.onTapItem,
    required this.onNext,
    super.key,
  });

  final OrderQuestion question;
  final List<int> tappedOrder;
  final bool answered;
  final bool en;
  final ValueChanged<int> onTapItem;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final lang = en ? Lang.en : Lang.vi;
    final correct =
        answered && _sameOrder(tappedOrder, question.correctOrder);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          VSSpacing.xl, VSSpacing.md, VSSpacing.xl, VSSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(question.prompt.resolve(lang), style: VSType.headline),
          const SizedBox(height: VSSpacing.xs),
          Text(
            en
                ? 'Tap them, earliest first.'
                : 'Chạm theo thứ tự, sự kiện sớm nhất trước.',
            style: VSType.caption.copyWith(color: VSColors.inkMuted),
          ),
          const SizedBox(height: VSSpacing.xl),
          for (var i = 0; i < question.items.length; i++) ...<Widget>[
            _OrderTile(
              key: ValueKey<int>(i),
              label: question.items[i].title.resolve(lang),
              rank: tappedOrder.contains(i) ? tappedOrder.indexOf(i) + 1 : null,
              correctYear: answered ? question.items[i].year : null,
              answered: answered,
              onTap: () => onTapItem(i),
            ),
            const SizedBox(height: VSSpacing.sm),
          ],
          if (answered) ...<Widget>[
            const SizedBox(height: VSSpacing.md),
            Container(
              padding: const EdgeInsets.all(VSSpacing.md),
              decoration: BoxDecoration(
                color: VSColors.goldWash,
                borderRadius: VSRadii.citationAll,
                border: Border.all(color: VSColors.goldBorder),
              ),
              child: Text(
                correct
                    ? (en ? 'Correct order!' : 'Đúng thứ tự!')
                    : (en
                        ? 'Not quite — each event\'s real year is shown '
                            'above; compare it with the order you tapped.'
                        : 'Chưa đúng — năm thật của mỗi sự kiện đã hiện ở '
                            'trên; so với thứ tự bạn vừa chạm.'),
                style: VSType.bodySmall,
              ),
            ),
            const SizedBox(height: VSSpacing.xl),
            _NextButton(en: en, onTap: onNext),
          ],
        ],
      ),
    );
  }

  bool _sameOrder(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({
    required this.label,
    required this.rank,
    required this.correctYear,
    required this.answered,
    required this.onTap,
    super.key,
  });

  final String label;
  final int? rank;
  final int? correctYear;
  final bool answered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: answered ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: VSSpacing.md, vertical: VSSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(
              color: rank != null ? VSColors.goldBright : VSColors.goldBorder),
          borderRadius: VSRadii.cardAll,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: VSColors.goldBorder),
              ),
              child: Text(
                rank?.toString() ?? '',
                style: VSType.caption.copyWith(color: VSColors.goldBright),
              ),
            ),
            const SizedBox(width: VSSpacing.md),
            Expanded(child: Text(label, style: VSType.body)),
            if (correctYear != null)
              Text(
                correctYear! < 0 ? '${-correctYear!} TCN' : '$correctYear',
                style: VSType.caption.copyWith(color: VSColors.inkMuted),
              ),
          ],
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.score,
    required this.total,
    required this.missed,
    required this.en,
    required this.onPlayAgain,
    required this.onClose,
  });

  final int score;
  final int total;
  final List<Question> missed;
  final bool en;
  final VoidCallback onPlayAgain;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final lang = en ? Lang.en : Lang.vi;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          VSSpacing.xl, VSSpacing.lg, VSSpacing.xl, VSSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Text(
              '$score/$total',
              style: VSType.displayLarge.copyWith(
                fontSize: 56,
                color: VSColors.goldBright,
              ),
            ),
          ),
          const SizedBox(height: VSSpacing.sm),
          Center(
            child: Text(
              en ? 'questions correct' : 'câu trả lời đúng',
              style: VSType.caption.copyWith(color: VSColors.inkMuted),
            ),
          ),
          const SizedBox(height: VSSpacing.xxl),
          if (missed.isNotEmpty) ...<Widget>[
            Text(en ? 'MISSED' : 'CÂU SAI', style: VSType.overline),
            const SizedBox(height: VSSpacing.sm),
            for (final q in missed)
              Padding(
                padding: const EdgeInsets.only(bottom: VSSpacing.sm),
                child: _MissedRow(question: q, lang: lang),
              ),
            const SizedBox(height: VSSpacing.lg),
          ],
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPlayAgain,
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    VSColors.goldBright.withValues(alpha: 0.16),
                    VSColors.gold.withValues(alpha: 0.10),
                  ],
                ),
                borderRadius: VSRadii.pillAll,
                border: Border.all(color: VSColors.gold.withValues(alpha: 0.6)),
              ),
              child: Text(
                en ? 'Play again' : 'Chơi lại',
                style: VSType.label.copyWith(color: VSColors.inkPrimary),
              ),
            ),
          ),
          const SizedBox(height: VSSpacing.md),
          TextButton(
            onPressed: onClose,
            child: Text(en ? 'Close' : 'Đóng',
                style: VSType.label.copyWith(color: VSColors.goldBright)),
          ),
        ],
      ),
    );
  }
}

class _MissedRow extends StatelessWidget {
  const _MissedRow({required this.question, required this.lang});
  final Question question;
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    final (String prompt, String eraSlug, String eventId) = switch (question) {
      McqQuestion q => (q.prompt.resolve(lang), q.source.eraSlug, q.source.eventId),
      OrderQuestion q => (
          q.prompt.resolve(lang),
          q.items.first.eraSlug,
          q.items.first.eventId,
        ),
    };
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => GoRouter.of(context).push('/era/$eraSlug/event/$eventId'),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: VSSpacing.md, vertical: VSSpacing.sm + 2),
        decoration: BoxDecoration(
          border: Border.all(color: VSColors.goldBorder),
          borderRadius: VSRadii.cardAll,
        ),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(prompt, style: VSType.bodySmall)),
            const Icon(Icons.chevron_right, size: 16, color: VSColors.gold),
          ],
        ),
      ),
    );
  }
}
