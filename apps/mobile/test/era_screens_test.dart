import 'dart:io';

import 'package:core_content/core_content.dart';
import 'package:experience/experience.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:viet_su/app_router.dart';
import 'package:viet_su/state/providers.dart';
import 'package:viet_su/widgets/timeline_bar.dart';

/// Content source backed by the repo's real content/ directory on disk.
class _DiskSource implements ContentSource {
  @override
  Future<List<String>> availableSlugs() async => <String>[
        'hong-bang-van-lang',
        'au-lac',
        'nha-trieu',
        'hai-ba-trung',
        'ba-trieu',
        'van-xuan',
        'mai-hac-de',
        'phung-hung',
        'khuc-thua-du',
        'ngo-quyen',
        'dinh-tien-hoang',
        'tien-le',
        'ly-thai-to',
        'ly-thai-tong',
        'ly-nhan-tong',
        'tran-thai-tong',
        'tran-hung-dao',
        'le-loi',
        'le-thanh-tong',
        'nam-bac-trieu',
        'trinh-nguyen',
        'tay-son',
        'gia-long',
        'minh-mang',
        'thieu-tri',
        'tu-duc',
        'can-vuong',
        'phong-trao-yeu-nuoc',
        'cach-mang-thang-tam',
        'dien-bien-phu',
      ];

  @override
  Future<String> loadEraJson(String slug) async =>
      // Sync read so the future resolves on a microtask the test clock flushes
      // (real async disk I/O would not complete under tester.pump).
      File('../../content/eras/$slug.json').readAsStringSync();

  @override
  Future<String> loadPeopleJson() async =>
      File('../../content/people.json').readAsStringSync();

  @override
  Future<String> loadPeriodsJson() async =>
      File('../../content/periods.json').readAsStringSync();
}

Future<GoRouter> _pumpAt(
  WidgetTester tester,
  String location,
  ExperienceTier tier,
) async {
  final container = ProviderContainer(overrides: <Override>[
    tierProvider.overrideWithValue(tier),
    contentRepositoryProvider
        .overrideWithValue(ContentRepository(_DiskSource())),
  ]);
  addTearDown(container.dispose);

  final router = container.read(routerProvider);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ExperienceScope(
        tier: tier,
        child: MaterialApp.router(
          routerConfig: router,
          theme: VSTheme.build(),
        ),
      ),
    ),
  );
  await tester.pump();

  // Navigate once the tree exists, then resolve the era future and let entrance
  // animations (flutter_animate staggered delays) fully complete so no timer is
  // left pending at teardown.
  router.go(location);
  await tester.pump(); // resolve the era future
  // Settle entrance animations. Callers use reduced tier (no infinite particle
  // ticker), so this terminates and drains flutter_animate's timers.
  await tester.pumpAndSettle();
  return router;
}

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  group('Era Hub', () {
    testWidgets('renders hero, editorial intro, chronicle, figures and CTA',
        (tester) async {
      await _pumpAt(tester, '/era/hong-bang-van-lang', ExperienceTier.reduced);

      // Hero band (first screen).
      expect(find.text('Hồng Bàng & Văn Lang'), findsOneWidget);
      expect(find.text('KỶ NGUYÊN KHỞI THỦY'), findsOneWidget);

      // The era-home facets live below the fold — scroll them in.
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('BỘ CHÍNH SỬ'),
        300,
        scrollable: scrollable,
      );
      // Chronicle provenance card + figures roster.
      expect(find.text('Đại Việt sử ký toàn thư'), findsOneWidget);
      expect(find.text('NHÂN VẬT'), findsOneWidget);
      expect(find.text('Kinh Dương Vương'), findsWidgets);

      // CTA into the timeline.
      await tester.scrollUntilVisible(
        find.text('Xem dòng sự kiện'),
        300,
        scrollable: scrollable,
      );
      expect(find.text('7 SỰ KIỆN · 1 BỘ CHÍNH SỬ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('EN toggle switches the CTA and count to English',
        (tester) async {
      await _pumpAt(tester, '/era/hong-bang-van-lang', ExperienceTier.reduced);

      // The toggle is pinned chrome on the first screen.
      await tester.tap(find.text('EN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Explore the events'),
        300,
        scrollable: scrollable,
      );
      expect(find.text('7 EVENTS · 1 CHRONICLE'), findsOneWidget);
      // Vietnamese CTA is gone.
      expect(find.text('Xem dòng sự kiện'), findsNothing);
    });

    testWidgets('back reaches Home (era list) when the stack was replaced',
        (tester) async {
      // Arrive at the hub via a stack-replacing go (nothing to pop) — this is
      // what happens after event-detail/timeline back navigation.
      await _pumpAt(tester, '/era/ngo-quyen', ExperienceTier.reduced);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Landed on Home: its top-right global-timeline icon is Home-only, and
      // there is no longer a back arrow.
      expect(find.byIcon(Icons.timeline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });
  });

  group('Era Timeline', () {
    testWidgets('renders every event card along the timeline', (tester) async {
      // Reduced tier: the flagship particle backdrop is identical to Home's and
      // is covered there; here we exercise the timeline's own card/spine logic.
      await _pumpAt(
          tester, '/era/hong-bang-van-lang/timeline', ExperienceTier.reduced);

      expect(find.text('Kinh Dương Vương lập nước'), findsOneWidget);
      expect(find.text('Lạc Long Quân & Âu Cơ'), findsOneWidget);
      // The timeline header overline.
      expect(find.text('DÒNG SỰ KIỆN'), findsOneWidget);
      // Seven events now (right-sized): scroll the lazy spine down through the
      // two added legends to the closing event.
      final scrollable = find.byType(Scrollable).first;
      for (final title in <String>[
        'Thánh Gióng phá giặc Ân',
        'Bánh chưng, bánh giày',
        'Thục Phán thay nhà Hùng',
      ]) {
        await tester.scrollUntilVisible(find.text(title), 250,
            scrollable: scrollable);
        expect(find.text(title), findsWidgets);
      }
      // Drain the entrance-animation timers of the cards scrolled into view.
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('Âu Lạc era (second era)', () {
    testWidgets('hub renders the era home and chronicle for Âu Lạc',
        (tester) async {
      await _pumpAt(tester, '/era/au-lac', ExperienceTier.reduced);

      expect(find.text('Âu Lạc'), findsWidgets);
      expect(find.text('KỶ NHÀ THỤC'), findsOneWidget);

      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('BỘ CHÍNH SỬ'),
        300,
        scrollable: scrollable,
      );
      expect(find.text('Đại Việt sử ký toàn thư'), findsOneWidget);
      expect(find.text('NHÂN VẬT'), findsOneWidget);
      expect(find.text('Thần Kim Quy'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('timeline lists the five Kỷ nhà Thục events', (tester) async {
      await _pumpAt(tester, '/era/au-lac/timeline', ExperienceTier.reduced);

      expect(find.text('An Dương Vương lập nước Âu Lạc'), findsOneWidget);
      expect(find.text('Xây thành Cổ Loa'), findsOneWidget);
      expect(find.text('Âu Lạc mất nước'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('event detail keeps the visible citation for Âu Lạc',
        (tester) async {
      await _pumpAt(
          tester, '/era/au-lac/event/no-than-kim-quy', ExperienceTier.reduced);

      expect(find.text('Nỏ thần Kim Quy'), findsOneWidget);
      expect(find.text('— Thần Kim Quy'), findsOneWidget);
      expect(find.text('NGUỒN'), findsOneWidget);
      expect(find.text('Đại Việt sử ký toàn thư'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Nhà Triệu era (third era)', () {
    testWidgets('timeline lists the Kỷ nhà Triệu events', (tester) async {
      await _pumpAt(tester, '/era/nha-trieu/timeline', ExperienceTier.reduced);

      expect(find.text('Triệu Vũ Đế lập nước Nam Việt'), findsOneWidget);
      expect(find.text('Nhà Triệu mất nước'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Lữ Gia has a chronicle-grounded bio', (tester) async {
      await _pumpAt(
          tester, '/era/nha-trieu/figure/lu-gia', ExperienceTier.reduced);

      expect(find.text('Lữ Gia'), findsWidgets);
      expect(find.text('TỂ TƯỚNG TRUNG NGHĨA'), findsOneWidget);
      expect(find.textContaining('ba đời làm tướng'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Hai Bà Trưng era (fourth era)', () {
    testWidgets('timeline lists the Kỷ Trưng Nữ Vương events', (tester) async {
      await _pumpAt(
          tester, '/era/hai-ba-trung/timeline', ExperienceTier.reduced);

      expect(find.text('Hai Bà Trưng khởi nghĩa'), findsOneWidget);
      // The finale, split into the counter-campaign and the sacrifice — scroll
      // the lazy spine down to reach the last two of six events.
      final scrollable = find.byType(Scrollable).first;
      for (final title in <String>['Mã Viện phản công', 'Hai Bà tuẫn tiết']) {
        await tester.scrollUntilVisible(find.text(title), 250,
            scrollable: scrollable);
        expect(find.text(title), findsWidgets);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Trưng Trắc has a chronicle-grounded bio', (tester) async {
      await _pumpAt(
          tester, '/era/hai-ba-trung/figure/trung-trac', ExperienceTier.reduced);

      expect(find.text('Trưng Trắc'), findsWidgets);
      expect(find.text('TRƯNG NỮ VƯƠNG'), findsOneWidget);
      expect(find.textContaining('Mê Linh'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Bà Triệu era (fifth era)', () {
    testWidgets('timeline lists the Kỷ thuộc Ngô events', (tester) async {
      await _pumpAt(tester, '/era/ba-trieu/timeline', ExperienceTier.reduced);

      expect(find.text('Ách đô hộ nhà Ngô'), findsOneWidget);
      final scrollable = find.byType(Scrollable).first;
      for (final title in <String>[
        'Khởi nghĩa năm Mậu Thìn',
        'Lục Dận đàn áp, Bà Triệu tuẫn tiết',
      ]) {
        await tester.scrollUntilVisible(find.text(title), 250,
            scrollable: scrollable);
        expect(find.text(title), findsWidgets);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Bà Triệu has a chronicle-grounded bio', (tester) async {
      await _pumpAt(
          tester, '/era/ba-trieu/figure/ba-trieu', ExperienceTier.reduced);

      expect(find.text('Bà Triệu'), findsWidgets);
      expect(find.text('NHỤY KIỀU TƯỚNG QUÂN'), findsOneWidget);
      expect(find.textContaining('Cửu Chân'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Vạn Xuân era (sixth era)', () {
    testWidgets('timeline lists the Kỷ nhà Tiền Lý events', (tester) async {
      await _pumpAt(tester, '/era/van-xuan/timeline', ExperienceTier.reduced);

      expect(find.text('Ách đô hộ nhà Lương'), findsOneWidget);
      final scrollable = find.byType(Scrollable).first;
      for (final title in <String>[
        'Lý Nam Đế lập nước Vạn Xuân',
        'Triệu Việt Vương và đầm Dạ Trạch',
      ]) {
        await tester.scrollUntilVisible(find.text(title), 250,
            scrollable: scrollable);
        expect(find.text(title), findsWidgets);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Lý Nam Đế has a chronicle-grounded bio', (tester) async {
      await _pumpAt(
          tester, '/era/van-xuan/figure/ly-nam-de', ExperienceTier.reduced);

      expect(find.text('Lý Nam Đế'), findsWidgets);
      expect(find.text('HOÀNG ĐẾ ĐẦU TIÊN'), findsOneWidget);
      expect(find.textContaining('Vạn Xuân'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Mai Hắc Đế era (seventh era)', () {
    testWidgets('timeline lists the Kỷ thuộc Đường events', (tester) async {
      await _pumpAt(tester, '/era/mai-hac-de/timeline', ExperienceTier.reduced);

      expect(find.text('Ách đô hộ nhà Đường'), findsOneWidget);
      final scrollable = find.byType(Scrollable).first;
      for (final title in <String>[
        'Xưng Mai Hắc Đế, dựng thành Vạn An',
        'Dương Tư Húc đàn áp',
      ]) {
        await tester.scrollUntilVisible(find.text(title), 250,
            scrollable: scrollable);
        expect(find.text(title), findsWidgets);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Mai Hắc Đế has a chronicle-grounded bio', (tester) async {
      await _pumpAt(
          tester, '/era/mai-hac-de/figure/mai-hac-de', ExperienceTier.reduced);

      expect(find.text('Mai Hắc Đế'), findsWidgets);
      expect(find.text('VUA ĐEN'), findsOneWidget);
      expect(find.textContaining('Hoan Châu'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Phùng Hưng era (eighth era)', () {
    testWidgets('timeline lists the Kỷ thuộc Đường events', (tester) async {
      await _pumpAt(tester, '/era/phung-hung/timeline', ExperienceTier.reduced);

      expect(find.text('Ách đô hộ và người Đường Lâm'), findsOneWidget);
      final scrollable = find.byType(Scrollable).first;
      for (final title in <String>[
        'Vây phủ thành, Cao Chính Bình chết',
        'Bố Cái Đại Vương',
      ]) {
        await tester.scrollUntilVisible(find.text(title), 250,
            scrollable: scrollable);
        expect(find.text(title), findsWidgets);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Phùng Hưng has a chronicle-grounded bio', (tester) async {
      await _pumpAt(
          tester, '/era/phung-hung/figure/phung-hung', ExperienceTier.reduced);

      expect(find.text('Phùng Hưng'), findsWidgets);
      expect(find.text('BỐ CÁI ĐẠI VƯƠNG'), findsOneWidget);
      expect(find.textContaining('Đường Lâm'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Họ Khúc era (ninth era)', () {
    testWidgets('timeline lists the Kỷ tự chủ họ Khúc events', (tester) async {
      await _pumpAt(tester, '/era/khuc-thua-du/timeline', ExperienceTier.reduced);

      expect(find.text('Nhà Đường suy vong'), findsOneWidget);
      final scrollable = find.byType(Scrollable).first;
      for (final title in <String>[
        'Khúc Thừa Dụ giành quyền tự chủ',
        'Khúc Thừa Mỹ và quân Nam Hán',
      ]) {
        await tester.scrollUntilVisible(find.text(title), 250,
            scrollable: scrollable);
        expect(find.text(title), findsWidgets);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Khúc Thừa Dụ has a chronicle-grounded bio', (tester) async {
      await _pumpAt(tester, '/era/khuc-thua-du/figure/khuc-thua-du',
          ExperienceTier.reduced);

      expect(find.text('Khúc Thừa Dụ'), findsWidgets);
      expect(find.text('KHÚC TIÊN CHÚA'), findsOneWidget);
      expect(find.textContaining('Đại La'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Ngô Quyền era (tenth era)', () {
    testWidgets('timeline lists the Kỷ nhà Ngô events', (tester) async {
      await _pumpAt(tester, '/era/ngo-quyen/timeline', ExperienceTier.reduced);

      expect(find.text('Dương Đình Nghệ bị hại'), findsOneWidget);
      final scrollable = find.byType(Scrollable).first;
      for (final title in <String>[
        'Kế đóng cọc Bạch Đằng',
        'Chiến thắng Bạch Đằng',
        'Ngô Quyền xưng vương',
      ]) {
        await tester.scrollUntilVisible(find.text(title), 250,
            scrollable: scrollable);
        expect(find.text(title), findsWidgets);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Ngô Quyền has a chronicle-grounded bio', (tester) async {
      await _pumpAt(
          tester, '/era/ngo-quyen/figure/ngo-quyen', ExperienceTier.reduced);

      expect(find.text('Ngô Quyền'), findsWidgets);
      expect(find.text('TIỀN NGÔ VƯƠNG'), findsOneWidget);
      expect(find.textContaining('Bạch Đằng'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Đinh Tiên Hoàng era (eleventh era)', () {
    testWidgets('timeline lists the Kỷ nhà Đinh events', (tester) async {
      await _pumpAt(
          tester, '/era/dinh-tien-hoang/timeline', ExperienceTier.reduced);

      expect(find.text('Loạn mười hai sứ quân'), findsOneWidget);
      final scrollable = find.byType(Scrollable).first;
      for (final title in <String>[
        'Lập nước Đại Cồ Việt',
        'Đỗ Thích thí nghịch',
      ]) {
        await tester.scrollUntilVisible(find.text(title), 250,
            scrollable: scrollable);
        expect(find.text(title), findsWidgets);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Đinh Tiên Hoàng has a chronicle-grounded bio', (tester) async {
      await _pumpAt(tester, '/era/dinh-tien-hoang/figure/dinh-tien-hoang',
          ExperienceTier.reduced);

      expect(find.text('Đinh Tiên Hoàng'), findsWidgets);
      expect(find.text('HOÀNG ĐẾ DỰNG NƯỚC ĐẠI CỒ VIỆT'), findsOneWidget);
      expect(find.textContaining('Hoa Lư'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Tiền Lê era (twelfth era)', () {
    testWidgets('timeline lists the Kỷ nhà Tiền Lê events', (tester) async {
      await _pumpAt(tester, '/era/tien-le/timeline', ExperienceTier.reduced);

      expect(find.text('Khoác long bào lên ngôi'), findsOneWidget);
      final scrollable = find.byType(Scrollable).first;
      for (final title in <String>[
        'Đại phá quân Tống trên Bạch Đằng',
        'Vua băng, nhà Tiền Lê suy',
      ]) {
        await tester.scrollUntilVisible(find.text(title), 250,
            scrollable: scrollable);
        expect(find.text(title), findsWidgets);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Lê Đại Hành carries a per-era imperial epithet',
        (tester) async {
      await _pumpAt(tester, '/era/tien-le/figure/le-hoan',
          ExperienceTier.reduced);

      expect(find.text('Lê Hoàn'), findsWidgets);
      expect(find.text('LÊ ĐẠI HÀNH · HOÀNG ĐẾ PHÁ TỐNG BÌNH CHIÊM'),
          findsOneWidget);
      expect(find.textContaining('Tiền Lê'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Lý Thái Tổ era (thirteenth era)', () {
    testWidgets('timeline lists the Kỷ nhà Lý events', (tester) async {
      await _pumpAt(tester, '/era/ly-thai-to/timeline', ExperienceTier.reduced);

      expect(find.text('Lý Công Uẩn lên ngôi'), findsOneWidget);
      final scrollable = find.byType(Scrollable).first;
      for (final title in <String>[
        'Chiếu dời đô, định đô Thăng Long',
        'Vua băng, loạn tam vương',
      ]) {
        await tester.scrollUntilVisible(find.text(title), 250,
            scrollable: scrollable);
        expect(find.text(title), findsWidgets);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Lý Thái Tổ has a chronicle-grounded bio', (tester) async {
      await _pumpAt(tester, '/era/ly-thai-to/figure/ly-thai-to',
          ExperienceTier.reduced);

      expect(find.text('Lý Thái Tổ'), findsWidgets);
      expect(find.text('VUA KHAI SÁNG NHÀ LÝ'), findsOneWidget);
      expect(find.textContaining('Thăng Long'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Lý Thái Tông – Thánh Tông era (fourteenth era)', () {
    testWidgets('timeline lists the twin-reign Lý events', (tester) async {
      await _pumpAt(
          tester, '/era/ly-thai-tong/timeline', ExperienceTier.reduced);

      expect(find.text('Ban bộ Hình thư'), findsOneWidget);
      final scrollable = find.byType(Scrollable).first;
      for (final title in <String>[
        'Đặt quốc hiệu Đại Việt',
        'Dựng Văn Miếu, mở Nho học',
      ]) {
        await tester.scrollUntilVisible(find.text(title), 250,
            scrollable: scrollable);
        expect(find.text(title), findsWidgets);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Ỷ Lan has a chronicle-grounded bio', (tester) async {
      await _pumpAt(tester, '/era/ly-thai-tong/figure/y-lan',
          ExperienceTier.reduced);

      expect(find.text('Ỷ Lan'), findsWidgets);
      expect(find.text('NGUYÊN PHI NHIẾP CHÍNH'), findsOneWidget);
      expect(find.textContaining('Quan Âm'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Lý Nhân Tông era (fifteenth era)', () {
    testWidgets('timeline lists the Nhân Tông & Thường Kiệt events',
        (tester) async {
      await _pumpAt(
          tester, '/era/ly-nhan-tong/timeline', ExperienceTier.reduced);

      expect(find.text('Nhân Tông lên ngôi, Ỷ Lan nhiếp chính'), findsOneWidget);
      final scrollable = find.byType(Scrollable).first;
      for (final title in <String>[
        'Tiên phát chế nhân — phá Ung, Khâm, Liêm',
        'Phòng tuyến Như Nguyệt, Nam quốc sơn hà',
      ]) {
        await tester.scrollUntilVisible(find.text(title), 250,
            scrollable: scrollable);
        expect(find.text(title), findsWidgets);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Lý Thường Kiệt has a chronicle-grounded bio', (tester) async {
      await _pumpAt(tester, '/era/ly-nhan-tong/figure/ly-thuong-kiet',
          ExperienceTier.reduced);

      expect(find.text('Lý Thường Kiệt'), findsWidgets);
      expect(find.text('THÁI ÚY PHÁ TỐNG'), findsOneWidget);
      expect(find.textContaining('Như Nguyệt'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Ỷ Lan carries a per-era Empress-Dowager epithet here',
        (tester) async {
      await _pumpAt(tester, '/era/ly-nhan-tong/figure/y-lan',
          ExperienceTier.reduced);

      expect(find.text('HOÀNG THÁI HẬU NHIẾP CHÍNH'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Trần Thái Tông era (sixteenth era)', () {
    testWidgets('timeline lists the Trần founding events', (tester) async {
      await _pumpAt(
          tester, '/era/tran-thai-tong/timeline', ExperienceTier.reduced);

      expect(find.text('Lý Chiêu Hoàng nhường ngôi'), findsOneWidget);
      final scrollable = find.byType(Scrollable).first;
      for (final title in <String>[
        'Phá quân Mông Cổ ở Đông Bộ Đầu',
        'Sùng Thiền, nhường ngôi Thái thượng hoàng',
      ]) {
        await tester.scrollUntilVisible(find.text(title), 250,
            scrollable: scrollable);
        expect(find.text(title), findsWidgets);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Trần Thủ Độ has a chronicle-grounded bio', (tester) async {
      await _pumpAt(tester, '/era/tran-thai-tong/figure/tran-thu-do',
          ExperienceTier.reduced);

      expect(find.text('Trần Thủ Độ'), findsWidgets);
      expect(find.text('THÁI SƯ DỰNG NGHIỆP TRẦN'), findsOneWidget);
      expect(find.textContaining('Đầu thần chưa rơi'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Trần Hưng Đạo era (seventeenth era, flagship peak)', () {
    testWidgets('timeline lists the Mongol-war events', (tester) async {
      await _pumpAt(
          tester, '/era/tran-hung-dao/timeline', ExperienceTier.reduced);

      expect(find.text('Hào khí Đông A'), findsOneWidget);
      final scrollable = find.byType(Scrollable).first;
      for (final title in <String>[
        'Diên Hồng và Hịch tướng sĩ',
        'Đại thắng Bạch Đằng',
        'Di ngôn giữ nước, hóa Đức Thánh Trần',
      ]) {
        await tester.scrollUntilVisible(find.text(title), 250,
            scrollable: scrollable);
        expect(find.text(title), findsWidgets);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Trần Hưng Đạo has a chronicle-grounded bio', (tester) async {
      await _pumpAt(tester, '/era/tran-hung-dao/figure/tran-hung-dao',
          ExperienceTier.reduced);

      expect(find.text('Trần Hưng Đạo'), findsWidgets);
      expect(find.text('QUỐC CÔNG TIẾT CHẾ · ĐỨC THÁNH TRẦN'), findsOneWidget);
      expect(find.textContaining('Bạch Đằng'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a flagship era is crowned with a ĐỈNH CAO peak marker',
        (tester) async {
      // On the global timeline, the flagship era carries the peak marker while
      // ordinary eras do not.
      await _pumpAt(tester, '/timeline', ExperienceTier.reduced);
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.text('Trần Hưng Đạo'), 300,
          scrollable: scrollable, maxScrolls: 160);
      await tester.pumpAndSettle();
      expect(find.text('ĐỈNH CAO'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Lê Lợi era (eighteenth era, flagship peak)', () {
    testWidgets('timeline lists the Lam Sơn events', (tester) async {
      await _pumpAt(tester, '/era/le-loi/timeline', ExperienceTier.reduced);

      expect(find.text('Thuộc Minh — nước mất nhà tan'), findsOneWidget);
      final scrollable = find.byType(Scrollable).first;
      for (final title in <String>[
        'Lê Lai đổi áo cứu chúa',
        'Chi Lăng – Xương Giang, chém Liễu Thăng',
        'Bình Ngô đại cáo, lập nhà Hậu Lê',
      ]) {
        await tester.scrollUntilVisible(find.text(title), 250,
            scrollable: scrollable);
        expect(find.text(title), findsWidgets);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Nguyễn Trãi has a chronicle-grounded bio', (tester) async {
      await _pumpAt(tester, '/era/le-loi/figure/nguyen-trai',
          ExperienceTier.reduced);

      expect(find.text('Nguyễn Trãi'), findsWidgets);
      expect(find.text('ỨC TRAI · TÁC GIẢ BÌNH NGÔ ĐẠI CÁO'), findsOneWidget);
      expect(find.textContaining('Bình Ngô'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Lê Thánh Tông era (nineteenth era)', () {
    testWidgets('timeline lists the Hồng Đức golden-age events', (tester) async {
      await _pumpAt(
          tester, '/era/le-thanh-tong/timeline', ExperienceTier.reduced);

      expect(find.text('Bình nạn Nghi Dân, Tư Thành lên ngôi'), findsOneWidget);
      final scrollable = find.byType(Scrollable).first;
      for (final title in <String>[
        'Thân chinh bình Chiêm, hạ thành Đồ Bàn',
        'Bia tiến sĩ, hội Tao Đàn, sử ký Toàn thư',
        'Hồng Đức thịnh trị, vua băng',
      ]) {
        await tester.scrollUntilVisible(find.text(title), 250,
            scrollable: scrollable);
        expect(find.text(title), findsWidgets);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Ngô Sĩ Liên has a chronicle-grounded bio', (tester) async {
      await _pumpAt(tester, '/era/le-thanh-tong/figure/ngo-si-lien',
          ExperienceTier.reduced);

      expect(find.text('Ngô Sĩ Liên'), findsWidgets);
      expect(find.text('SỬ THẦN · SOẠN GIẢ ĐẠI VIỆT SỬ KÝ TOÀN THƯ'),
          findsOneWidget);
      expect(find.textContaining('Toàn thư'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Nam – Bắc triều era (twentieth era)', () {
    testWidgets('timeline lists the division-era events', (tester) async {
      await _pumpAt(
          tester, '/era/nam-bac-trieu/timeline', ExperienceTier.reduced);

      expect(find.text('Mạc Đăng Dung cướp ngôi, lập nhà Mạc'), findsOneWidget);
      final scrollable = find.byType(Scrollable).first;
      for (final title in <String>[
        'Nguyễn Kim phò Lê, dựng Nam triều',
        'Nguyễn Hoàng vào trấn Thuận Hóa',
        'Trịnh Tùng diệt Mạc, mở nền chúa Trịnh',
      ]) {
        await tester.scrollUntilVisible(find.text(title), 250,
            scrollable: scrollable);
        expect(find.text(title), findsWidgets);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Nguyễn Hoàng has a chronicle-grounded bio', (tester) async {
      await _pumpAt(tester, '/era/nam-bac-trieu/figure/nguyen-hoang',
          ExperienceTier.reduced);

      expect(find.text('Nguyễn Hoàng'), findsWidgets);
      expect(find.text('CHÚA TIÊN · KHỞI TỔ CÁC CHÚA NGUYỄN'), findsOneWidget);
      expect(find.textContaining('Thuận Hóa'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Trịnh – Nguyễn era (twenty-first era)', () {
    testWidgets('timeline lists the division-war events', (tester) async {
      await _pumpAt(
          tester, '/era/trinh-nguyen/timeline', ExperienceTier.reduced);

      expect(find.text('Đàng Trong tách cõi, được Đào Duy Từ'), findsOneWidget);
      final scrollable = find.byType(Scrollable).first;
      for (final title in <String>[
        'Đào Duy Từ đắp Lũy Thầy',
        'Mở đất phương Nam, thương cảng Hội An',
        'Đình chiến, sông Gianh chia đôi đất nước',
      ]) {
        await tester.scrollUntilVisible(find.text(title), 250,
            scrollable: scrollable);
        expect(find.text(title), findsWidgets);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Đào Duy Từ has a chronicle-grounded bio', (tester) async {
      await _pumpAt(tester, '/era/trinh-nguyen/figure/dao-duy-tu',
          ExperienceTier.reduced);

      expect(find.text('Đào Duy Từ'), findsWidgets);
      expect(find.text('KHAI QUỐC CÔNG THẦN ĐÀNG TRONG · NGƯỜI DỰNG LŨY THẦY'),
          findsOneWidget);
      expect(find.textContaining('Lũy Thầy'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Tây Sơn era (twenty-second era, flagship peak)', () {
    testWidgets('timeline lists the Tây Sơn events', (tester) async {
      await _pumpAt(tester, '/era/tay-son/timeline', ExperienceTier.reduced);

      expect(find.text('Ba anh em dựng cờ Tây Sơn'), findsOneWidget);
      final scrollable = find.byType(Scrollable).first;
      for (final title in <String>[
        'Rạch Gầm – Xoài Mút, đại phá quân Xiêm',
        'Ngọc Hồi – Đống Đa, đại phá quân Thanh',
        'Canh tân đất nước, vua đột ngột băng hà',
      ]) {
        await tester.scrollUntilVisible(find.text(title), 250,
            scrollable: scrollable);
        expect(find.text(title), findsWidgets);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Quang Trung has a chronicle-grounded bio', (tester) async {
      await _pumpAt(
          tester, '/era/tay-son/figure/quang-trung', ExperienceTier.reduced);

      expect(find.text('Nguyễn Huệ · Quang Trung'), findsWidgets);
      expect(
          find.text(
              'HOÀNG ĐẾ QUANG TRUNG · NGƯỜI ANH HÙNG ÁO VẢI ĐẠI PHÁ QUÂN THANH'),
          findsOneWidget);
      expect(find.textContaining('Kỷ Dậu'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Gia Long era (twenty-third era)', () {
    testWidgets('timeline lists the Nguyễn founding events', (tester) async {
      await _pumpAt(tester, '/era/gia-long/timeline', ExperienceTier.reduced);

      expect(find.text('Nguyễn Ánh lưu lạc, nuôi chí phục quốc'), findsOneWidget);
      final scrollable = find.byType(Scrollable).first;
      for (final title in <String>[
        'Bắc tiến diệt Tây Sơn, thu giang sơn về một mối',
        'Lên ngôi Gia Long, đặt quốc hiệu Việt Nam',
        'Dựng kinh thành Huế, định luật Gia Long',
      ]) {
        await tester.scrollUntilVisible(find.text(title), 250,
            scrollable: scrollable);
        expect(find.text(title), findsWidgets);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Gia Long has a chronicle-grounded bio', (tester) async {
      await _pumpAt(
          tester, '/era/gia-long/figure/gia-long', ExperienceTier.reduced);

      expect(find.text('Nguyễn Ánh · Gia Long'), findsWidgets);
      expect(
          find.text(
              'HOÀNG ĐẾ KHAI SÁNG NHÀ NGUYỄN · NGƯỜI THỐNG NHẤT GIANG SƠN'),
          findsOneWidget);
      expect(find.textContaining('Việt Nam'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Minh Mạng era (twenty-fourth era)', () {
    testWidgets('timeline lists the Minh Mạng reign events', (tester) async {
      await _pumpAt(tester, '/era/minh-mang/timeline', ExperienceTier.reduced);

      expect(find.text('Minh Mạng lên ngôi, vị vua cần chính'), findsOneWidget);
      final scrollable = find.byType(Scrollable).first;
      for (final title in <String>[
        'Bãi tổng trấn, chia nước làm ba mươi tỉnh',
        'Mở mang bờ cõi, đặt quốc hiệu Đại Nam',
        'Cấm đạo, bế quan tỏa cảng, vua băng',
      ]) {
        await tester.scrollUntilVisible(find.text(title), 250,
            scrollable: scrollable);
        expect(find.text(title), findsWidgets);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Nguyễn Công Trứ has a chronicle-grounded bio', (tester) async {
      await _pumpAt(tester, '/era/minh-mang/figure/nguyen-cong-tru',
          ExperienceTier.reduced);

      expect(find.text('Nguyễn Công Trứ'), findsWidgets);
      expect(
          find.text('DOANH ĐIỀN SỨ · NHÀ KHAI HOANG, TƯỚNG LĨNH, THI NHÂN'),
          findsOneWidget);
      expect(find.textContaining('Tiền Hải'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Thiệu Trị era (twenty-fifth era)', () {
    testWidgets('timeline lists the Thiệu Trị reign events', (tester) async {
      await _pumpAt(tester, '/era/thieu-tri/timeline', ExperienceTier.reduced);

      expect(find.text('Thiệu Trị nối ngôi, giữ nếp tiên triều'), findsOneWidget);
      final scrollable = find.byType(Scrollable).first;
      for (final title in <String>[
        'Ông vua thi nhân, chuộng văn hiến',
        'Pháo hạm Pháp bắn phá Đà Nẵng',
        'Vua băng, Tự Đức nối ngôi',
      ]) {
        await tester.scrollUntilVisible(find.text(title), 250,
            scrollable: scrollable);
        expect(find.text(title), findsWidgets);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Nguyễn Tri Phương has a chronicle-grounded bio', (tester) async {
      await _pumpAt(tester, '/era/thieu-tri/figure/nguyen-tri-phuong',
          ExperienceTier.reduced);

      expect(find.text('Nguyễn Tri Phương'), findsWidgets);
      expect(find.text('DANH TƯỚNG TRỤ CỘT · BẬC TRUNG LIỆT CHỐNG PHÁP'),
          findsOneWidget);
      expect(find.textContaining('Đà Nẵng'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Tự Đức era (twenty-sixth era)', () {
    testWidgets('timeline lists the French-conquest events', (tester) async {
      await _pumpAt(tester, '/era/tu-duc/timeline', ExperienceTier.reduced);

      expect(find.text('Tự Đức lên ngôi, nước khép mình trước bão'),
          findsOneWidget);
      final scrollable = find.byType(Scrollable).first;
      for (final title in <String>[
        'Pháp đánh Đà Nẵng, Nguyễn Tri Phương chặn giặc',
        'Nghĩa quân Nam Kỳ đứng lên đánh Pháp',
        'Hà Nội thất thủ, vua băng, nước vào vòng bảo hộ',
      ]) {
        await tester.scrollUntilVisible(find.text(title), 250,
            scrollable: scrollable);
        expect(find.text(title), findsWidgets);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Nguyễn Trung Trực has a chronicle-grounded bio', (tester) async {
      await _pumpAt(tester, '/era/tu-duc/figure/nguyen-trung-truc',
          ExperienceTier.reduced);

      expect(find.text('Nguyễn Trung Trực'), findsWidgets);
      expect(find.text('ANH HÙNG KHÁNG PHÁP · NGƯỜI ĐỐT TÀU ÉT-PÊ-RĂNG'),
          findsOneWidget);
      expect(find.textContaining('Nhật Tảo'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Cần Vương era (twenty-seventh era)', () {
    testWidgets('timeline lists the Cần Vương events', (tester) async {
      await _pumpAt(tester, '/era/can-vuong/timeline', ExperienceTier.reduced);

      expect(find.text('Tứ nguyệt tam vương, hòa ước bảo hộ'), findsOneWidget);
      final scrollable = find.byType(Scrollable).first;
      for (final title in <String>[
        'Chiếu Cần Vương, muôn dân giúp nước',
        'Vua Hàm Nghi bị bắt, đày sang Algérie',
        'Hùm thiêng Yên Thế, ngọn lửa chưa tắt',
      ]) {
        await tester.scrollUntilVisible(find.text(title), 250,
            scrollable: scrollable);
        expect(find.text(title), findsWidgets);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Phan Đình Phùng has a chronicle-grounded bio', (tester) async {
      await _pumpAt(tester, '/era/can-vuong/figure/phan-dinh-phung',
          ExperienceTier.reduced);

      expect(find.text('Phan Đình Phùng'), findsWidgets);
      expect(find.text('LÃNH TỤ KHỞI NGHĨA HƯƠNG KHÊ · ĐÌNH NGUYÊN TIẾN SĨ'),
          findsOneWidget);
      expect(find.textContaining('Hương Khê'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Global Timeline', () {
    testWidgets('threads every era and its events into one chronology',
        (tester) async {
      await _pumpAt(tester, '/timeline', ExperienceTier.reduced);

      // Header reflects the full corpus; the top of the spine is the first era.
      expect(find.text('NIÊN BIỂU'), findsOneWidget);
      expect(find.text('30 kỷ nguyên · 170 sự kiện'), findsOneWidget);
      expect(find.text('Hồng Bàng & Văn Lang'), findsOneWidget);
      expect(find.text('Kinh Dương Vương lập nước'), findsOneWidget);
      // The one spine runs down through every era to the last — scroll all the
      // way to the finale (Ngô Quyền) and its Bạch Đằng victory.
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Chiến thắng Bạch Đằng'),
        300,
        scrollable: scrollable,
        maxScrolls: 120,
      );
      expect(find.text('Chiến thắng Bạch Đằng'), findsWidgets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Home corner icon opens the global timeline', (tester) async {
      await _pumpAt(tester, '/', ExperienceTier.reduced);

      // The timeline affordance sits in Home's top-right corner.
      await tester.tap(find.byIcon(Icons.timeline_rounded));
      await tester.pumpAndSettle();

      // Landed on the global timeline.
      expect(find.text('NIÊN BIỂU'), findsOneWidget);
      expect(find.text('Hồng Bàng & Văn Lang'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('groups the timeline under dynasty headers', (tester) async {
      await _pumpAt(tester, '/timeline', ExperienceTier.reduced);

      // The first dynasty band leads the spine.
      expect(find.text('BÌNH MINH DỰNG NƯỚC'), findsOneWidget);
      expect(find.text('Hồng Bàng – Âu Lạc'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keyword filter narrows the spine to matching events',
        (tester) async {
      await _pumpAt(tester, '/timeline', ExperienceTier.reduced);
      // Unfiltered, the very first event is present.
      expect(find.text('Kinh Dương Vương lập nước'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Đống Đa');
      await tester.pumpAndSettle();

      // The matching Tây Sơn event stays; unrelated first-era events drop out,
      // and the header switches to a result count.
      expect(
          find.text('Ngọc Hồi – Đống Đa, đại phá quân Thanh'), findsWidgets);
      expect(find.text('Kinh Dương Vương lập nước'), findsNothing);
      expect(find.textContaining('kết quả'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keyword filter ignores diacritics', (tester) async {
      await _pumpAt(tester, '/timeline', ExperienceTier.reduced);

      // Unaccented query still folds to match accented content.
      await tester.enterText(find.byType(TextField), 'bach dang');
      await tester.pumpAndSettle();

      expect(find.text('Chiến thắng Bạch Đằng'), findsWidgets);
      expect(find.text('Kinh Dương Vương lập nước'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('clearing the filter restores the full timeline',
        (tester) async {
      await _pumpAt(tester, '/timeline', ExperienceTier.reduced);

      await tester.enterText(find.byType(TextField), 'Đống Đa');
      await tester.pumpAndSettle();
      expect(find.text('Kinh Dương Vương lập nước'), findsNothing);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Kinh Dương Vương lập nước'), findsOneWidget);
      expect(find.text('30 kỷ nguyên · 170 sự kiện'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Dynasty hub (Home)', () {
    testWidgets('opens on the first dynasty and its first era', (tester) async {
      await _pumpAt(tester, '/', ExperienceTier.reduced);

      // Dynasty identity in the top chrome…
      expect(find.text('Hồng Bàng – Âu Lạc'), findsOneWidget);
      // …and the opening era's hero.
      expect(find.text('Hồng Bàng & Văn Lang'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('swiping up moves to the next dynasty', (tester) async {
      await _pumpAt(tester, '/', ExperienceTier.reduced);
      expect(find.text('Hồng Bàng – Âu Lạc'), findsOneWidget);

      // Vertical axis = dynasties: fling the outer pager up to the 2nd dynasty.
      await tester.fling(
          find.byKey(const ValueKey<String>('dynasty-pager')),
          const Offset(0, -500),
          1200);
      await tester.pumpAndSettle();

      expect(find.text('Nhà Triệu'), findsOneWidget);
      expect(find.text('Hồng Bàng – Âu Lạc'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Territory atlas', () {
    testWidgets('global timeline map button opens the atlas at the first era',
        (tester) async {
      await _pumpAt(tester, '/timeline', ExperienceTier.reduced);

      await tester.tap(find.byIcon(Icons.map_outlined));
      await tester.pumpAndSettle();

      expect(find.text('BẢN ĐỒ LÃNH THỔ'), findsOneWidget);
      expect(find.text('Văn Lang'), findsWidgets); // first snapshot title
      expect(tester.takeException(), isNull);
    });

    testWidgets('atlas renders with the timeline scrubber', (tester) async {
      await _pumpAt(tester, '/map', ExperienceTier.reduced);

      expect(find.text('BẢN ĐỒ LÃNH THỔ'), findsOneWidget);
      expect(find.byType(TimelineBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('era hub map button opens that era\'s dynasty snapshot',
        (tester) async {
      await _pumpAt(tester, '/era/trinh-nguyen', ExperienceTier.reduced);

      expect(find.byIcon(Icons.map_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.map_outlined));
      await tester.pumpAndSettle();
      // The map opens on the Trịnh–Nguyễn snapshot, not the first era.
      expect(find.text('Trịnh – Nguyễn'), findsWidgets);
      expect(find.text('Đàng Ngoài'), findsWidgets); // legend force
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the always-on present-day reference outline',
        (tester) async {
      await _pumpAt(tester, '/map', ExperienceTier.reduced);

      // The dashed present-day outline is applied directly (no toggle), and the
      // hint explains it. The old "Nay" chip must be gone.
      expect(find.text('Nay'), findsNothing);
      expect(find.textContaining('Nét đứt'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Character Detail', () {
    testWidgets('renders portrait, epithet, bio and appearances', (tester) async {
      await _pumpAt(tester, '/era/au-lac/figure/cao-lo', ExperienceTier.reduced);

      expect(find.text('Cao Lỗ'), findsWidgets);
      expect(find.text('TƯỚNG CHẾ NỎ'), findsOneWidget);
      expect(find.textContaining('Linh Quang Kim Quy'), findsOneWidget);

      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('XUẤT HIỆN TRONG'),
        200,
        scrollable: scrollable,
      );
      // Cao Lỗ appears in the crossbow event.
      expect(find.text('Nỏ thần Kim Quy'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a figure avatar opens the character page',
        (tester) async {
      await _pumpAt(tester, '/era/au-lac', ExperienceTier.reduced);

      // The hub's ListView builds all children eagerly, so bring the roster
      // tile into the viewport before tapping it.
      await tester.ensureVisible(find.text('An Dương Vương'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('An Dương Vương'));
      await tester.pumpAndSettle();

      // Landed on An Dương Vương's detail page.
      expect(find.text('VUA ÂU LẠC'), findsOneWidget);
      expect(find.textContaining('Cổ Loa'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Event Detail', () {
    const path = '/era/hong-bang-van-lang/event/kinh-duong-vuong-lap-nuoc';

    testWidgets('renders body, pull-quote and visible citation (VI)',
        (tester) async {
      await _pumpAt(tester, path, ExperienceTier.reduced);

      expect(find.text('Kinh Dương Vương lập nước'), findsOneWidget);
      expect(find.text('01 / 07'), findsOneWidget);
      // Body.
      expect(
        find.textContaining('đặt tên nước là Xích Quỷ'),
        findsOneWidget,
      );
      // Chronicle pull-quote + attribution.
      expect(find.text('Ta là giống rồng, nàng là giống tiên…'),
          findsOneWidget);
      expect(find.text('— Lạc Long Quân'), findsOneWidget);
      // Figures strip.
      expect(find.text('NHÂN VẬT'), findsOneWidget);
      expect(find.text('Kinh Dương Vương'), findsOneWidget);
      expect(find.text('Lạc Long Quân'), findsOneWidget);
      expect(find.text('Bố Rồng'), findsOneWidget);
      // Read-more control.
      expect(find.text('ĐỌC THÊM'), findsOneWidget);
      // Related-events section was removed (it read as a "continue" link).
      expect(find.text('SỰ KIỆN LIÊN QUAN'), findsNothing);
      // Visible citation.
      expect(find.text('NGUỒN'), findsOneWidget);
      expect(find.text('Đại Việt sử ký toàn thư'), findsOneWidget);
      expect(find.text('Ngoại kỷ · Quyển 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('swipe left advances to the next event and dismisses the hint',
        (tester) async {
      await _pumpAt(tester, path, ExperienceTier.reduced);

      expect(find.text('01 / 07'), findsOneWidget);
      expect(find.text('Vuốt để chuyển sự kiện'), findsOneWidget);

      // Swipe left → next event (it slides in from the right).
      await tester.fling(find.byType(PageView), const Offset(-360, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('02 / 07'), findsOneWidget);
      expect(find.text('01 / 07'), findsNothing);
      expect(find.text('Lạc Long Quân & Âu Cơ'), findsWidgets);

      // The hint has faded out.
      final opacity = tester
          .widget<AnimatedOpacity>(find.ancestor(
            of: find.text('Vuốt để chuyển sự kiện'),
            matching: find.byType(AnimatedOpacity),
          ))
          .opacity;
      expect(opacity, 0);
    });

    testWidgets('swipe left past an era boundary enters the next era',
        (tester) async {
      // Open the LAST event of Hồng Bàng (07/07); swiping left should not
      // dead-end but carry into Âu Lạc's first event (01/05).
      await _pumpAt(tester, '/era/hong-bang-van-lang/event/thuc-phan-thay-nha-hung',
          ExperienceTier.reduced);
      expect(find.text('07 / 07'), findsOneWidget);

      await tester.fling(find.byType(PageView), const Offset(-360, 0), 1000);
      await tester.pumpAndSettle();

      // Counter reset into the new chapter; Âu Lạc's opening event is shown.
      expect(find.text('01 / 05'), findsOneWidget);
      expect(find.text('An Dương Vương lập nước Âu Lạc'), findsWidgets);
    });

    testWidgets('back after a cross-era swipe lands on the new era timeline',
        (tester) async {
      // Open Hồng Bàng's last event, swipe into Âu Lạc, then press back.
      await _pumpAt(tester, '/era/hong-bang-van-lang/event/thuc-phan-thay-nha-hung',
          ExperienceTier.reduced);
      await tester.fling(find.byType(PageView), const Offset(-360, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('An Dương Vương lập nước Âu Lạc'), findsWidgets);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Landed on Âu Lạc's event list — not the origin era.
      expect(find.text('DÒNG SỰ KIỆN'), findsOneWidget);
      expect(find.text('Âu Lạc'), findsWidgets);
      expect(find.text('An Dương Vương lập nước Âu Lạc'), findsWidgets);
      expect(find.text('Hồng Bàng & Văn Lang'), findsNothing);
    });

    testWidgets('swipe left advances within the Bà Triệu era', (tester) async {
      // Regression: within the last era, swipe LEFT still advances to the next
      // event (never reversed).
      await _pumpAt(tester, '/era/ba-trieu/event/ach-do-ho-nha-ngo',
          ExperienceTier.reduced);
      expect(find.text('01 / 04'), findsOneWidget);

      await tester.fling(find.byType(PageView), const Offset(-360, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('02 / 04'), findsOneWidget);
      expect(find.text('Người con gái Cửu Chân'), findsWidgets);
    });

    testWidgets('read-more reveals the fuller chronicle account', (tester) async {
      await _pumpAt(tester, path, ExperienceTier.reduced);

      // Collapsed: fuller account not shown yet.
      expect(find.textContaining('bắc giáp hồ Động Đình'), findsNothing);
      await tester.tap(find.text('ĐỌC THÊM'));
      await tester.pumpAndSettle();
      expect(find.textContaining('bắc giáp hồ Động Đình'), findsOneWidget);
      expect(find.text('THU GỌN'), findsOneWidget);
    });

    testWidgets('EN toggle switches body and citation to English',
        (tester) async {
      await _pumpAt(tester, path, ExperienceTier.reduced);

      await tester.tap(find.text('EN'));
      await tester.pumpAndSettle();

      expect(find.text('SOURCE'), findsOneWidget);
      expect(find.text('Outer Records · Book 1'), findsOneWidget);
      expect(find.textContaining('named the country Xích Quỷ'), findsOneWidget);
      // Figures section localized too.
      expect(find.text('FIGURES'), findsOneWidget);
      expect(find.text('The Dragon Father'), findsOneWidget);
      // Vietnamese source label is gone.
      expect(find.text('NGUỒN'), findsNothing);
    });
  });
}
