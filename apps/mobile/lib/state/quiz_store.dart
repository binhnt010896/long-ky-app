import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

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

/// Câu đố's whole remembered state: the best score per scope, plus which
/// calendar day's "Câu đố hôm nay" was last completed (so its card can show a
/// ✓ without needing to re-run the quiz). No streaks, no history beyond this —
/// see the delicate-UI rule.
class QuizProgress {
  const QuizProgress({this.bests = const <String, BestScore>{}, this.dailyDoneDate});

  final Map<String, BestScore> bests;

  /// `yyyy-mm-dd` of the last completed daily quiz, or null.
  final String? dailyDoneDate;

  static const QuizProgress empty = QuizProgress();

  BestScore? bestFor(String modeKey) => bests[modeKey];

  bool isDailyDoneOn(DateTime day) => dailyDoneDate == _dateKey(day);

  QuizProgress withResult(String modeKey, int score, int total,
      {DateTime? markDailyDoneOn}) {
    final current = bests[modeKey];
    final improved = current == null || score > current.score;
    return QuizProgress(
      bests: <String, BestScore>{
        ...bests,
        if (improved) modeKey: BestScore(score: score, total: total),
      },
      dailyDoneDate: markDailyDoneOn != null
          ? _dateKey(markDailyDoneOn)
          : dailyDoneDate,
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
  /// so that day's card can show its ✓.
  Future<QuizProgress> recordResult({
    required String modeKey,
    required int score,
    required int total,
    DateTime? dailyOn,
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
      );
    } catch (_) {
      // A corrupted or unreadable file is not worth failing the quiz over.
      return _cached = QuizProgress.empty;
    }
  }

  @override
  Future<QuizProgress> recordResult({
    required String modeKey,
    required int score,
    required int total,
    DateTime? dailyOn,
  }) async {
    final current = await load();
    final updated = current.withResult(modeKey, score, total,
        markDailyDoneOn: dailyOn);
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
        }));
        await tmp.rename(file.path);
      }
    } catch (_) {
      // In-memory _cached already reflects the result even if the write
      // failed — the session stays consistent even without persistence.
    }
    return updated;
  }
}

final quizStoreProvider = Provider<QuizStore>((ref) => FileQuizStore());

final quizProgressProvider = FutureProvider<QuizProgress>((ref) {
  return ref.watch(quizStoreProvider).load();
});
