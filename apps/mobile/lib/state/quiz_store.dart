import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../telemetry/telemetry.dart';

/// A remembered best score for one quiz scope ("daily", "random", a period or
/// an era) — see [QuizStore.modeKey].
class BestScore {
  const BestScore({required this.score, required this.total});
  final int score;
  final int total;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'score': score,
        'total': total,
      };

  static BestScore? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final score = json['score'];
    final total = json['total'];
    if (score is! int || total is! int) return null;
    return BestScore(score: score, total: total);
  }
}

/// How the first attempt of one day's "Câu đố hôm nay" went: one mark per
/// question, in order. This is what the share card shows — a replay never
/// changes it, so everyone's shared grid is their first try.
class DailyFirst {
  const DailyFirst({required this.date, required this.marks});

  /// `yyyy-mm-dd` of that day.
  final String date;

  /// True for a right answer, in question order.
  final List<bool> marks;

  int get score => marks.where((m) => m).length;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'date': date,
        'marks': marks,
      };

  static DailyFirst? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final date = json['date'];
    final marks = json['marks'];
    if (date is! String || marks is! List || marks.isEmpty) return null;
    if (!marks.every((m) => m is bool)) return null;
    return DailyFirst(date: date, marks: List<bool>.unmodifiable(marks.cast<bool>()));
  }
}

/// Câu đố's whole remembered state: the best score per scope, which calendar
/// day's "Câu đố hôm nay" was last completed (so its card can show a ✓ without
/// needing to re-run the quiz), and how that day's first attempt went (for the
/// share card). No history beyond this. The app's one streak lives in the unlock feature
/// (unlock_store.dart), by the user's decision of 2026-10-24.
class QuizProgress {
  const QuizProgress({
    this.bests = const <String, BestScore>{},
    this.dailyDoneDate,
    this.dailyFirst,
  });

  final Map<String, BestScore> bests;

  /// `yyyy-mm-dd` of the last completed daily quiz, or null.
  final String? dailyDoneDate;

  /// The first attempt of the last day the daily quiz was completed, or null
  /// (never played, or last completed before this was recorded).
  final DailyFirst? dailyFirst;

  static const QuizProgress empty = QuizProgress();

  BestScore? bestFor(String modeKey) => bests[modeKey];

  bool isDailyDoneOn(DateTime day) => dailyDoneDate == _dateKey(day);

  /// [day]'s first daily attempt, or null if it isn't known.
  DailyFirst? dailyFirstOn(DateTime day) =>
      dailyFirst?.date == _dateKey(day) ? dailyFirst : null;

  /// [marks] are the per-question results of this run. They are kept only when
  /// this is the first completed daily run of [markDailyDoneOn]'s day — a
  /// replay, or a day already completed before marks were recorded, leaves
  /// [dailyFirst] alone.
  QuizProgress withResult(String modeKey, int score, int total,
      {DateTime? markDailyDoneOn, List<bool>? marks}) {
    final current = bests[modeKey];
    final improved = current == null || score > current.score;
    final today = markDailyDoneOn == null ? null : _dateKey(markDailyDoneOn);
    final isFirstOfDay =
        today != null && marks != null && dailyDoneDate != today;
    return QuizProgress(
      bests: <String, BestScore>{
        ...bests,
        if (improved) modeKey: BestScore(score: score, total: total),
      },
      dailyDoneDate: today ?? dailyDoneDate,
      dailyFirst: isFirstOfDay
          ? DailyFirst(date: today, marks: List<bool>.unmodifiable(marks))
          : dailyFirst,
    );
  }
}

String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Mode-key builders — one small vocabulary shared by the store and the quiz
/// screens, so a scope always maps to the same key.
abstract final class QuizModeKey {
  static const String daily = 'daily';
  static const String random = 'random';
  static String period(String periodId) => 'period:$periodId';
  static String era(String eraSlug) => 'era:$eraSlug';
}

/// The Câu đố persistence seam — a real file-backed store in the app, an
/// in-memory fake in tests.
abstract class QuizStore {
  Future<QuizProgress> load();

  /// Records a finished quiz's result, keeping the better of the old and new
  /// best for [modeKey]. Pass [dailyOn] when this run was "Câu đố hôm nay",
  /// so that day's card can show its ✓, and [marks] (one per question) so the
  /// day's first attempt can be shared.
  Future<QuizProgress> recordResult({
    required String modeKey,
    required int score,
    required int total,
    DateTime? dailyOn,
    List<bool>? marks,
  });
}

/// Persists to a small JSON file via `path_provider`, mirroring
/// `ContentSync`'s on-disk pattern. On web (no meaningful persistent
/// app-private storage) it keeps progress in memory for the session only.
class FileQuizStore implements QuizStore {
  QuizProgress? _cached;

  static Future<File?> _storeFile() async {
    if (kIsWeb) return null;
    final dir = await getApplicationSupportDirectory();
    final quizDir = Directory('${dir.path}/quiz');
    if (!quizDir.existsSync()) quizDir.createSync(recursive: true);
    return File('${quizDir.path}/progress.json');
  }

  @override
  Future<QuizProgress> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    try {
      final file = await _storeFile();
      if (file == null || !file.existsSync()) return _cached = QuizProgress.empty;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map<String, dynamic>) return _cached = QuizProgress.empty;
      final bestsRaw = raw['bests'];
      final bests = <String, BestScore>{
        if (bestsRaw is Map<String, dynamic>)
          for (final entry in bestsRaw.entries)
            if (BestScore.fromJson(entry.value) case final b?) entry.key: b,
      };
      final dailyDoneDate = raw['dailyDoneDate'];
      return _cached = QuizProgress(
        bests: bests,
        dailyDoneDate: dailyDoneDate is String ? dailyDoneDate : null,
        dailyFirst: DailyFirst.fromJson(raw['dailyFirst']),
      );
    } catch (e, s) {
      // A corrupted or unreadable file is not worth failing the quiz over.
      reportNonFatal(e, s, reason: 'FileQuizStore.load');
      return _cached = QuizProgress.empty;
    }
  }

  @override
  Future<QuizProgress> recordResult({
    required String modeKey,
    required int score,
    required int total,
    DateTime? dailyOn,
    List<bool>? marks,
  }) async {
    final current = await load();
    final updated = current.withResult(modeKey, score, total,
        markDailyDoneOn: dailyOn, marks: marks);
    _cached = updated;
    try {
      final file = await _storeFile();
      if (file != null) {
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsString(jsonEncode(<String, dynamic>{
          'bests': <String, dynamic>{
            for (final e in updated.bests.entries) e.key: e.value.toJson(),
          },
          if (updated.dailyDoneDate != null)
            'dailyDoneDate': updated.dailyDoneDate,
          if (updated.dailyFirst != null)
            'dailyFirst': updated.dailyFirst!.toJson(),
        }));
        await tmp.rename(file.path);
      }
    } catch (e, s) {
      // In-memory _cached already reflects the result even if the write
      // failed — the session stays consistent even without persistence.
      reportNonFatal(e, s, reason: 'FileQuizStore.recordResult');
    }
    return updated;
  }
}

final quizStoreProvider = Provider<QuizStore>((ref) => FileQuizStore());

final quizProgressProvider = FutureProvider<QuizProgress>((ref) {
  return ref.watch(quizStoreProvider).load();
});
