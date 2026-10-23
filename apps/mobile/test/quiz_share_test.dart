import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_su/state/quiz_share.dart';
import 'package:viet_su/state/quiz_store.dart';

Directory _mockPathProvider(TestWidgetsFlutterBinding binding) {
  final dir = Directory.systemTemp.createTempSync('quiz_share_test');
  addTearDown(() => dir.deleteSync(recursive: true));
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
    if (call.method == 'getApplicationSupportDirectory') return dir.path;
    return null;
  });
  addTearDown(
      () => binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
  return dir;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('dailyShareText', () {
    const marks = <bool>[true, true, false, true, true];

    test('Vietnamese: date, one square per question, score, link', () {
      expect(
        dailyShareText(day: DateTime(2026, 10, 23), marks: marks, en: false),
        'Long Ký · Câu đố hôm nay 23/10/2026\n🟨🟨⬛🟨🟨  4/5\nlong-ky.com/get',
      );
    });

    test('English title, same grid', () {
      final text = dailyShareText(day: DateTime(2026, 1, 5), marks: marks, en: true);
      expect(text.split('\n').first, 'Long Ký · Today\'s quiz 05/01/2026');
      expect(text.split('\n')[1], '🟨🟨⬛🟨🟨  4/5');
    });

    test('never reveals a question or an answer: only the fixed shape', () {
      final text = dailyShareText(day: DateTime(2026, 10, 23), marks: marks, en: false);
      final lines = text.split('\n');
      expect(lines, hasLength(3));
      expect(RegExp(r'^[🟨⬛]+  \d+/\d+$').hasMatch(lines[1]), isTrue);
    });
  });

  group('QuizProgress daily first attempt', () {
    final monday = DateTime(2026, 10, 19);
    final tuesday = DateTime(2026, 10, 20);

    test('the first completed daily run of a day is recorded', () {
      final p = QuizProgress.empty.withResult('daily', 3, 5,
          markDailyDoneOn: monday, marks: const [true, false, true, true, false]);
      expect(p.dailyFirstOn(monday)!.marks, [true, false, true, true, false]);
      expect(p.dailyFirstOn(monday)!.score, 3);
      expect(p.dailyFirstOn(tuesday), isNull);
    });

    test('a replay the same day never overwrites it, though the best score improves', () {
      var p = QuizProgress.empty.withResult('daily', 2, 5,
          markDailyDoneOn: monday, marks: const [true, false, false, true, false]);
      p = p.withResult('daily', 5, 5,
          markDailyDoneOn: monday, marks: const [true, true, true, true, true]);
      expect(p.dailyFirstOn(monday)!.score, 2);
      expect(p.bestFor('daily')!.score, 5);
    });

    test('the next day records a fresh first attempt', () {
      var p = QuizProgress.empty.withResult('daily', 2, 5,
          markDailyDoneOn: monday, marks: const [true, false, false, true, false]);
      p = p.withResult('daily', 4, 5,
          markDailyDoneOn: tuesday, marks: const [true, true, false, true, true]);
      expect(p.dailyFirstOn(tuesday)!.score, 4);
      expect(p.dailyFirstOn(monday), isNull);
    });

    test('a day completed before marks existed gets no share card from a replay', () {
      const before = QuizProgress(dailyDoneDate: '2026-10-19');
      final p = before.withResult('daily', 5, 5,
          markDailyDoneOn: monday, marks: const [true, true, true, true, true]);
      expect(p.dailyFirstOn(monday), isNull);
    });

    test('other modes never record a first attempt', () {
      final p = QuizProgress.empty.withResult('random', 7, 10,
          marks: List<bool>.filled(10, true));
      expect(p.dailyFirst, isNull);
    });

    test('DailyFirst.fromJson ignores malformed data', () {
      expect(DailyFirst.fromJson(null), isNull);
      expect(DailyFirst.fromJson({'date': '2026-10-19', 'marks': <Object>[]}), isNull);
      expect(DailyFirst.fromJson({'date': '2026-10-19', 'marks': [true, 1]}), isNull);
      expect(DailyFirst.fromJson({'marks': [true]}), isNull);
    });
  });

  group('FileQuizStore', () {
    test('persists the first attempt and an old progress file still loads', () async {
      final dir = _mockPathProvider(TestWidgetsFlutterBinding.instance);
      final day = DateTime(2026, 10, 19);
      await FileQuizStore().recordResult(
          modeKey: 'daily',
          score: 4,
          total: 5,
          dailyOn: day,
          marks: const [true, true, false, true, true]);
      final reloaded = await FileQuizStore().load();
      expect(reloaded.dailyFirstOn(day)!.marks, [true, true, false, true, true]);
      expect(reloaded.bestFor('daily')!.score, 4);

      // A file written by a build before this field existed.
      File('${dir.path}/quiz/progress.json').writeAsStringSync(
          '{"bests":{"daily":{"score":3,"total":5}},"dailyDoneDate":"2026-10-18"}');
      final old = await FileQuizStore().load();
      expect(old.bestFor('daily')!.score, 3);
      expect(old.dailyFirst, isNull);
      expect(old.dailyDoneDate, '2026-10-18');
    });
  });
}
