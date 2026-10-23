import 'dart:convert';

import 'package:admin/util/clip_player.dart';
import 'package:admin/util/narration.dart';
import 'package:admin/widgets/narration_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _jobs() => jsonEncode({
      'jobs': [
        {
          'id': 'events/a80',
          'type': 'events',
          'slug': 'a80',
          'chars': 238,
          'hash': 'abc123',
          'status': 'done',
          'durationSecs': 19.84,
          'text': 'A80: 80 năm Quốc khánh.',
        },
        {'id': 'people/le-loi', 'chars': 10, 'hash': 'h', 'status': 'pending', 'text': 't'},
      ],
    });

class _FakePlayer extends ClipPlayer {
  _FakePlayer(this.url);
  final String url;
  bool _playing = false;
  @override
  bool get playing => _playing;
  @override
  Duration get position => Duration.zero;
  @override
  Duration? get duration => const Duration(seconds: 20);
  @override
  String? get error => null;
  @override
  void toggle() {
    _playing = !_playing;
    notifyListeners();
  }

  @override
  void seek(Duration to) {}
}

void main() {
  group('NarrationIndex', () {
    test('finds a clip by kind and slug and builds the cache-busted URL', () {
      final c = NarrationIndex.fromJson(_jobs()).clipFor('events', 'a80')!;
      expect(c.isReady, isTrue);
      expect(c.url, 'https://media.binh-nt.dev/audio/vi/events/a80.mp3?v=abc123');
      expect(c.duration, const Duration(milliseconds: 19840));
      expect(formatClock(c.duration!), '0:19');
    });

    test('a pending job is found but not ready', () {
      final idx = NarrationIndex.fromJson(_jobs());
      expect(idx.clipFor('people', 'le-loi')!.isReady, isFalse);
      expect(idx.readyClipFor('people', 'le-loi'), isNull);
      expect(idx.clipFor('events', 'nope'), isNull);
    });

    test('a missing or malformed file yields an empty index', () {
      expect(NarrationIndex.fromJson(null).length, 0);
      expect(NarrationIndex.fromJson('{not json').length, 0);
    });
  });

  group('NarrationPanel', () {
    Widget host(Widget w) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: w)));

    testWidgets('empty state when the item has no clip', (tester) async {
      await tester.pumpWidget(host(const NarrationPanel(clip: null)));
      expect(find.text('No narration for this item.'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });

    testWidgets('queued job says it is not generated yet', (tester) async {
      final clip = NarrationIndex.fromJson(_jobs()).clipFor('people', 'le-loi');
      await tester.pumpWidget(host(NarrationPanel(clip: clip)));
      expect(find.textContaining('not generated yet'), findsOneWidget);
    });

    testWidgets('plays and pauses, creating the player only on first play', (tester) async {
      final clip = NarrationIndex.fromJson(_jobs()).clipFor('events', 'a80');
      final created = <String>[];
      await tester.pumpWidget(host(NarrationPanel(
        clip: clip,
        playerFactory: (url) {
          created.add(url);
          return _FakePlayer(url);
        },
      )));
      expect(created, isEmpty);
      expect(find.text('0:00 / 0:19'), findsOneWidget);
      expect(find.text('238 chars'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();
      expect(created, ['https://media.binh-nt.dev/audio/vi/events/a80.mp3?v=abc123']);
      expect(find.byIcon(Icons.pause), findsOneWidget);

      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump();
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(created, hasLength(1));
    });

    testWidgets('shows the script when expanded', (tester) async {
      final clip = NarrationIndex.fromJson(_jobs()).clipFor('events', 'a80');
      await tester.pumpWidget(host(NarrationPanel(clip: clip)));
      await tester.tap(find.text('Script read aloud'));
      await tester.pumpAndSettle();
      expect(find.text('A80: 80 năm Quốc khánh.'), findsOneWidget);
    });
  });
}
