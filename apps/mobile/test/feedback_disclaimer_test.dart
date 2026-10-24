import 'dart:convert';
import 'dart:io';

import 'package:core_content/core_content.dart';
import 'package:core_content/testing.dart';
import 'package:core_domain/core_domain.dart';
import 'package:experience/experience.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:viet_su/app_router.dart';
import 'package:viet_su/feedback/feedback.dart';
import 'package:viet_su/screens/character/character_detail_screen.dart';
import 'package:viet_su/screens/character/standalone_character_screen.dart';
import 'package:viet_su/screens/event/event_detail_screen.dart';
import 'package:viet_su/screens/event/standalone_event_screen.dart';
import 'package:viet_su/screens/sanh/disclaimer_screen.dart';
import 'package:viet_su/state/content_sync.dart';
import 'package:viet_su/state/providers.dart';
import 'package:viet_su/telemetry/route_telemetry.dart';
import 'package:viet_su/telemetry/telemetry.dart';
import 'package:viet_su/telemetry/telemetry_settings.dart';

const String _aloneEvent = 'su-kien-rieng-bao-sai';
const String _alonePerson = 'nguoi-rieng-bao-sai';
const String _inEraEvent = 'trieu-vu-de-lap-nam-viet';

/// The real content, plus a standalone person and a standalone event.
class _Content extends DiskContentSource {
  _Content() : super(Directory('../../content'));

  @override
  Future<String> loadPeopleJson() async {
    final base = jsonDecode(await super.loadPeopleJson()) as Map<String, dynamic>;
    (base['people'] as List).add(<String, dynamic>{
      'id': _alonePerson,
      'name': {'vi': 'Người Riêng', 'en': 'Lone Person'},
      'bio': {'vi': 'Tiểu sử.', 'en': 'Bio.'},
    });
    return jsonEncode(base);
  }

  @override
  Future<String> loadStandaloneEventsJson() async => jsonEncode(<String, dynamic>{
        'schemaVersion': 1,
        'events': [
          <String, dynamic>{
            'id': _aloneEvent,
            'kind': 'historical',
            'year': {'value': 1698, 'display': {'vi': '1698', 'en': '1698'}},
            'title': {'vi': 'Sự kiện riêng', 'en': 'Standalone event'},
            'summary': {'vi': 'Tóm tắt.'},
            'body': {'vi': 'Nội dung.'},
            'citation': {'work': 'Đại Nam thực lục'},
            'figureIds': [_alonePerson],
          },
        ],
      });
}

class _Events implements Telemetry {
  final List<(String, Map<String, Object>)> events = [];
  @override
  Future<void> event(String name, [Map<String, Object> params = const {}]) async =>
      events.add((name, params));
  @override
  Future<void> screen(String name, [Map<String, Object> params = const {}]) async {}
  @override
  Future<void> recordError(Object error, StackTrace stackTrace,
      {String? reason, bool fatal = false}) async {}
  @override
  Future<void> setEnabled(bool enabled) async {}
  @override
  Future<void> setCommonProperty(String key, Object value) async {}
}

class _Store implements TelemetrySettingsStore {
  @override
  Future<bool> load() async => true;
  @override
  Future<void> setEnabled(bool enabled) async {}
}

class _Harness {
  _Harness(this.router, this.opened, this.sent, this.telemetry);
  final GoRouter router;
  final List<Uri> opened;

  /// The (subject, body) of every report posted to the feedback server.
  final List<(String, String)> sent;
  final _Events telemetry;
  /// The top page's location — a `push` leaves the configuration's uri alone.
  String get location =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;
}

Future<_Harness> _pump(WidgetTester tester, String location,
    {Lang lang = Lang.vi, bool opens = true, bool delivers = true}) async {
  final opened = <Uri>[];
  final sent = <(String, String)>[];
  final telemetry = _Events();
  final container = ProviderContainer(overrides: [
    contentRepositoryProvider.overrideWithValue(ContentRepository(_Content())),
    telemetryProvider.overrideWithValue(telemetry),
    telemetrySettingsStoreProvider.overrideWithValue(_Store()),
    langProvider.overrideWith((ref) => lang),
    activeContentVersionProvider.overrideWith((ref) => 42),
    urlOpenerProvider.overrideWithValue((uri) async {
      opened.add(uri);
      return opens;
    }),
    feedbackSenderProvider.overrideWithValue((subject, body) async {
      sent.add((subject, body));
      return delivers;
    }),
  ]);
  addTearDown(container.dispose);
  final router = container.read(routerProvider);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: ExperienceScope(
      tier: ExperienceTier.reduced,
      child: MaterialApp.router(routerConfig: router, theme: VSTheme.build()),
    ),
  ));
  router.go(location);
  await _settle(tester);
  return _Harness(router, opened, sent, telemetry);
}

/// Each async hop (redirect, content futures) needs its own frame.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Picks "Nội dung", types a note and taps Send in the open sheet.
Future<void> _fillAndSend(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('feedback-kind-text')));
  await tester.pump();
  await tester.enterText(find.byKey(const Key('feedback-note')), 'Sai năm');
  await tester.tap(find.byKey(const Key('feedback-send')));
  await _settle(tester);
}

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390, 1200);
    view.devicePixelRatio = 1.0;
  });

  group('the report text', () {
    const target = FeedbackTarget(
      type: 'event',
      id: 'tran-hung-dao',
      title: 'Hội nghị Diên Hồng & Bình Than',
      route: '/era/nha-tran/event/tran-hung-dao',
    );
    const ctx = FeedbackContext(
        contentVersion: 7, appVersion: '1.1.2', platform: 'android', lang: Lang.vi);

    test('the subject names the item', () {
      expect(feedbackSubject(target),
          '[Long Ký] Báo sai sót: Hội nghị Diên Hồng & Bình Than (event tran-hung-dao)');
    });

    test('the body carries the choice, note, page and versions', () {
      final body = feedbackBody(
          target: target, ctx: ctx, kind: FeedbackKind.image, note: '  Sai ảnh ');
      expect(body, contains('Sai ở đâu: Hình ảnh'));
      expect(body, contains('Ghi chú: Sai ảnh'));
      expect(body, contains('Trang: /era/nha-tran/event/tran-hung-dao'));
      expect(body, contains('Bản nội dung: 7'));
      expect(body, contains('Ứng dụng: 1.1.2 (android)'));
      expect(body, contains('Ngôn ngữ: vi'));
    });

    test('kFeedbackEmail is the one address', () {
      expect(kFeedbackEmail, 'help@long-ky.com');
    });
  });

  group('Báo sai sót is on every detail page', () {
    final pages = <String, (String, Type)>{
      'era figure': ('/era/nha-trieu/figure/trieu-da', CharacterDetailScreen),
      'standalone person': ('/nhan-vat/$_alonePerson', StandaloneCharacterScreen),
      'era event': ('/era/nha-trieu/event/$_inEraEvent', EventDetailScreen),
      'standalone event': ('/su-kien/$_aloneEvent', StandaloneEventScreen),
    };
    for (final MapEntry(key: name, value: (location, screen)) in pages.entries) {
      testWidgets(name, (tester) async {
        final h = await _pump(tester, location);
        expect(find.byType(screen), findsOneWidget);
        expect(find.byKey(FeedbackButton.buttonKey), findsOneWidget);
        await tester.tap(find.byKey(FeedbackButton.buttonKey));
        await _settle(tester);
        expect(find.byType(FeedbackSheet), findsOneWidget);
        expect(find.text('Bạn thấy sai ở đâu?'), findsOneWidget);
        expect(h.telemetry.events.single.$1, 'feedback_opened');
      });
    }
  });

  testWidgets('sending posts the report with the page details', (tester) async {
    final h = await _pump(tester, '/su-kien/$_aloneEvent');
    await tester.tap(find.byKey(FeedbackButton.buttonKey));
    await _settle(tester);
    expect(h.telemetry.events.single.$2,
        <String, Object>{'type': 'event', 'id': _aloneEvent});
    await _fillAndSend(tester);
    final (subject, body) = h.sent.single;
    expect(subject, '[Long Ký] Báo sai sót: Sự kiện riêng (event $_aloneEvent)');
    expect(body, contains('Sai ở đâu: Nội dung'));
    expect(body, contains('Ghi chú: Sai năm'));
    expect(body, contains('Trang: /su-kien/$_aloneEvent'));
    expect(body, contains('Bản nội dung: 42'));
    // Never the reader's own mail app.
    expect(h.opened, isEmpty);
    // The sheet closes once the server has it, and says thanks.
    expect(find.byType(FeedbackSheet), findsNothing);
    expect(find.text('Đã gửi, cảm ơn bạn'), findsOneWidget);
    expect(h.telemetry.events.map((e) => e.$1), contains('feedback_sent'));
  });

  testWidgets('Send waits for a choice', (tester) async {
    final h = await _pump(tester, '/su-kien/$_aloneEvent');
    await tester.tap(find.byKey(FeedbackButton.buttonKey));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('feedback-send')));
    await _settle(tester);
    expect(h.sent, isEmpty);
  });

  testWidgets('a failed send keeps the form and lets the reader retry',
      (tester) async {
    final h = await _pump(tester, '/nhan-vat/$_alonePerson', delivers: false);
    await tester.tap(find.byKey(FeedbackButton.buttonKey));
    await _settle(tester);
    await _fillAndSend(tester);
    expect(find.byType(FeedbackSheet), findsOneWidget);
    expect(find.byKey(const Key('feedback-error')), findsOneWidget);
    expect(find.text('Sai năm'), findsOneWidget);
    expect(h.telemetry.events.map((e) => e.$1), isNot(contains('feedback_sent')));
    await tester.tap(find.byKey(const Key('feedback-send')));
    await _settle(tester);
    expect(h.sent, hasLength(2));
  });

  testWidgets('a swipe in the era pager reports the event on screen',
      (tester) async {
    final h = await _pump(tester, '/era/nha-trieu/event/$_inEraEvent');
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await _settle(tester);
    await tester.tap(find.byKey(FeedbackButton.buttonKey));
    await _settle(tester);
    final id = h.telemetry.events
        .singleWhere((e) => e.$1 == 'feedback_opened')
        .$2['id'];
    expect(id, isNot(_inEraEvent));
  });

  group('the disclaimer page', () {
    testWidgets('renders in Vietnamese', (tester) async {
      await _pump(tester, kDisclaimerRoute);
      expect(find.byType(DisclaimerScreen), findsOneWidget);
      expect(find.text(DisclaimerScreen.titleVi), findsOneWidget);
      expect(find.text('Nhiều hình ảnh được tạo bằng AI'), findsOneWidget);
      await tester.scrollUntilVisible(find.byKey(const Key('disclaimer-email')), 300);
      expect(find.text(kFeedbackEmail), findsOneWidget);
    });

    testWidgets('renders in English', (tester) async {
      await _pump(tester, kDisclaimerRoute, lang: Lang.en);
      expect(find.text(DisclaimerScreen.titleEn), findsOneWidget);
      expect(find.text('Many images are made with AI'), findsOneWidget);
    });

    testWidgets('the email address opens a mail draft', (tester) async {
      final h = await _pump(tester, kDisclaimerRoute);
      final link = find.byKey(const Key('disclaimer-email'));
      await tester.scrollUntilVisible(link, 300);
      await tester.tap(link);
      await tester.pump();
      expect(h.opened.single, Uri(scheme: 'mailto', path: kFeedbackEmail));
    });

    testWidgets('opens from the Sảnh', (tester) async {
      final h = await _pump(tester, '/sanh');
      final row = find.byKey(const ValueKey<String>('sanh-row-/luu-y'));
      await tester.scrollUntilVisible(row, 200);
      await tester.tap(row);
      await _settle(tester);
      expect(h.location, kDisclaimerRoute);
      expect(find.byType(DisclaimerScreen), findsOneWidget);
    });

    testWidgets('opens from the About page', (tester) async {
      final h = await _pump(tester, '/sanh/gioi-thieu');
      final link = find.byKey(const Key('about-disclaimer-link'));
      await tester.scrollUntilVisible(link, 200);
      await tester.tap(link);
      await _settle(tester);
      expect(h.location, kDisclaimerRoute);
    });

    testWidgets('opens from the ⓘ beside an image caption', (tester) async {
      final h = await _pump(tester, '/era/nha-trieu/event/$_inEraEvent');
      expect(find.text('Minh họa · phong cách sơn mài'), findsWidgets);
      final info = find.byKey(DisclaimerInfoButton.buttonKey);
      await tester.tap(info.first);
      await _settle(tester);
      expect(h.location, kDisclaimerRoute);
      expect(find.byType(DisclaimerScreen), findsOneWidget);
    });

    test('logs as its own screen', () {
      expect(mapUriToScreen(Uri.parse(kDisclaimerRoute))?.name, 'disclaimer');
    });
  });

  test('Android can open a mail draft (url_launcher needs the query)', () {
    final m = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(m, contains('android.intent.action.SENDTO'));
    expect(m, contains('android:scheme="mailto"'));
  });
}
