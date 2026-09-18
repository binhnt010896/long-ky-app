import 'dart:convert';
import 'dart:io';

import 'package:core_domain/core_domain.dart';
import 'package:experience/experience.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_su/screens/home/home_screen.dart';
import 'package:viet_su/screens/home/widgets/particle_field.dart';
import 'package:viet_su/state/providers.dart';

PeopleRegistry _people() => PeopleRegistry.fromJson(
    jsonDecode(File('../../content/people.json').readAsStringSync())
        as Map<String, dynamic>);

Era _loadEra(String slug) => Era.fromJson(
    jsonDecode(File('../../content/eras/$slug.json').readAsStringSync())
        as Map<String, dynamic>,
    _people());

Era _loadHongBang() => _loadEra('hong-bang-van-lang');

Period _loadPeriod(String id) {
  final registry = PeriodRegistry.fromJson(
      jsonDecode(File('../../content/periods.json').readAsStringSync())
          as Map<String, dynamic>);
  return registry[id]!;
}

Period _loadHongBangPeriod() => _loadPeriod('hong-bang');

/// A two-dynasty hub: Hồng Bàng (two eras) then Nhà Triệu (one era). Lets tests
/// exercise both hub axes and the remembered-position providers.
List<Dynasty> _twoDynasties() => <Dynasty>[
      Dynasty(
        period: _loadPeriod('hong-bang'),
        eras: <Era>[_loadEra('hong-bang-van-lang'), _loadEra('au-lac')],
      ),
      Dynasty(period: _loadPeriod('nha-trieu'), eras: <Era>[_loadEra('nha-trieu')]),
    ];

/// Pumps the hub against an explicit container (so tests can read/seed the
/// remembered-position providers), at reduced tier so pumpAndSettle terminates.
Future<ProviderContainer> _pumpHub(
  WidgetTester tester,
  List<Dynasty> dynasties, {
  List<Override> overrides = const <Override>[],
}) async {
  final container = ProviderContainer(overrides: <Override>[
    tierProvider.overrideWithValue(ExperienceTier.reduced),
    dynastiesProvider.overrideWith((ref) async => dynasties),
    ...overrides,
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: ExperienceScope(
            tier: ExperienceTier.reduced, child: HomeScreen()),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
  return container;
}

/// The horizontal (era) pager for the on-screen dynasty. With a single dynasty
/// there is exactly one; `.last` is the inner pager beneath the outer vertical.
PageController _eraController(WidgetTester tester) {
  final pagers = tester
      .widgetList<PageView>(find.byType(PageView))
      .where((p) => p.scrollDirection == Axis.horizontal)
      .toList();
  return pagers.last.controller!;
}

Future<void> _pumpHome(WidgetTester tester, ExperienceTier tier) async {
  final dynasty =
      Dynasty(period: _loadHongBangPeriod(), eras: <Era>[_loadHongBang()]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        tierProvider.overrideWithValue(tier),
        dynastiesProvider.overrideWith((ref) async => <Dynasty>[dynasty]),
      ],
      child: MaterialApp(
        home: ExperienceScope(tier: tier, child: const HomeScreen()),
      ),
    ),
  );
  // Resolve the FutureProvider, then let one frame of particles tick.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  // A phone-sized surface so layout matches the target and we can catch overflow.
  setUp(() {
    // ignore: deprecated_member_use
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .views.first;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  testWidgets('renders the Hồng Bàng hero at flagship tier', (tester) async {
    await _pumpHome(tester, ExperienceTier.flagship);

    // The era hero (horizontal axis) …
    expect(find.text('Hồng Bàng & Văn Lang'), findsOneWidget);
    expect(find.text('KỶ NGUYÊN KHỞI THỦY'), findsOneWidget);
    expect(find.text('2879 – 258 TCN'), findsOneWidget);
    // … and the dynasty identity (vertical axis) in the top chrome.
    expect(find.text('Hồng Bàng – Âu Lạc'), findsOneWidget);
    // Flagship draws ambient particles.
    expect(find.byType(ParticleField), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders at reduced tier with no particles and no overflow',
      (tester) async {
    await _pumpHome(tester, ExperienceTier.reduced);

    expect(find.text('Hồng Bàng & Văn Lang'), findsOneWidget);
    // Reduced tier drops particles — degradation, not a platform branch.
    expect(find.byType(ParticleField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('remembered hub position', () {
    testWidgets('records the era column when scrolling within a dynasty',
        (tester) async {
      final container = await _pumpHub(tester, <Dynasty>[
        Dynasty(
          period: _loadPeriod('hong-bang'),
          eras: <Era>[_loadEra('hong-bang-van-lang'), _loadEra('au-lac')],
        ),
      ]);

      // Fling the horizontal era pager to the 2nd era (Âu Lạc).
      await tester.fling(
        find.byWidgetPredicate(
            (w) => w is PageView && w.scrollDirection == Axis.horizontal),
        const Offset(-400, 0),
        1200,
      );
      await tester.pumpAndSettle();

      // The move is remembered against the dynasty's period id.
      expect(container.read(hubEraIndexProvider)['hong-bang'], 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('restores the remembered era column on rebuild', (tester) async {
      await _pumpHub(
        tester,
        <Dynasty>[
          Dynasty(
            period: _loadPeriod('hong-bang'),
            eras: <Era>[_loadEra('hong-bang-van-lang'), _loadEra('au-lac')],
          ),
        ],
        overrides: <Override>[
          hubEraIndexProvider
              .overrideWith((ref) => <String, int>{'hong-bang': 1}),
        ],
      );

      // The inner era pager opens on the remembered page, not page 0.
      expect(_eraController(tester).page?.round(), 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('restores the remembered dynasty on rebuild', (tester) async {
      await _pumpHub(
        tester,
        _twoDynasties(),
        overrides: <Override>[
          hubDynastyIndexProvider.overrideWith((ref) => 1),
        ],
      );

      // Opens on the 2nd dynasty (Nhà Triệu), not the first.
      expect(find.text('Nhà Triệu'), findsWidgets);
      expect(find.text('Hồng Bàng – Âu Lạc'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
