import 'package:core_domain/core_domain.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import 'screens/chao_co/chao_co_screen.dart';
import 'screens/character/character_detail_screen.dart';
import 'screens/character/standalone_character_screen.dart';
import 'screens/era/era_hub_screen.dart';
import 'screens/era/era_timeline_screen.dart';
import 'state/providers.dart';
import 'state/today_provider.dart';
import 'state/visit_store.dart';
import 'screens/event/event_detail_screen.dart';
import 'screens/event/standalone_event_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/prototype/territory_map_demo_screen.dart';
import 'screens/quiz/quiz_home_screen.dart';
import 'screens/quiz/quiz_play_screen.dart';
import 'screens/sanh/about_screen.dart';
import 'screens/sanh/disclaimer_screen.dart';
import 'screens/sanh/sanh_screen.dart';
import 'screens/streets/street_map_screen.dart';
import 'screens/timeline/global_timeline_screen.dart';
import 'telemetry/route_telemetry.dart';
import 'telemetry/telemetry.dart';

/// App routes.
///  - `/`                       Home — the vertical era stack.
///  - `/timeline`               Global Timeline — every era's events in order
///                              (pushed from Home's corner affordance).
///  - `/sanh`                   Sảnh — the hall behind the Long Ký seal.
///  - `/sanh/gioi-thieu`        Về Long Ký — sources, images, version.
///  - `/luu-y`                  Lưu ý về hình ảnh & nội dung — how the images
///                              are made, and how to report a mistake.
///  - `/chao-co`                Chào cờ — the daily flag salute.
///  - `/map`                    Territory atlas.
///  - `/duong-pho`              Streets named for history (old HCMC);
///                              optional `?street=<id>` opens on that street.
///  - `/era/:slug`              Era Hub — parallax hero + facets.
///  - `/era/:slug/timeline`     Era Timeline — this era's events.
///  - `/era/:slug/event/:id`    Event Detail — hero, body, pull-quote, citation.
///  - `/su-kien/:id`            Any event by id only. An event in an era
///                              redirects to its `/era/:slug/event/:id`; a
///                              standalone one (no era) opens its own page.
///  - `/era/:slug/figure/:id`   Character Detail — portrait, bio, appearances.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/timeline',
        builder: (context, state) => const GlobalTimelineScreen(),
      ),
      // Territory atlas — the map across history. Optional ?year= snaps to the
      // nearest snapshot (e.g. from an era's date).
      GoRoute(
        path: '/map',
        builder: (context, state) => TerritoryMapDemoScreen(
          initialEra: state.uri.queryParameters['era'],
        ),
      ),
      // Đường phố mang tên sử — old-HCMC streets named after a figure/event.
      GoRoute(
        path: '/duong-pho',
        builder: (context, state) => StreetMapScreen(
          initialStreetId: state.uri.queryParameters['street'],
        ),
      ),
      // The Sảnh opens out of the seal in Home's top-right corner.
      GoRoute(
        path: '/sanh',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const SanhScreen(),
          transitionDuration: VSMotion.reveal,
          reverseTransitionDuration: VSMotion.reveal,
          transitionsBuilder: (context, animation, _, child) {
            final a = CurvedAnimation(
                parent: animation, curve: VSMotion.emphasized);
            return FadeTransition(
              opacity: a,
              child: ScaleTransition(
                alignment: Alignment.topRight,
                scale: Tween<double>(begin: 0.96, end: 1).animate(a),
                child: child,
              ),
            );
          },
        ),
        routes: <RouteBase>[
          GoRoute(
            path: 'gioi-thieu',
            builder: (context, state) => const AboutScreen(),
          ),
          // Câu đố — every question is generated from published content
          // (see QuizGenerator); the play route is a pure function of its
          // query params, so "play again" is just a push with a new seed.
          GoRoute(
            path: 'cau-do',
            builder: (context, state) => const QuizHomeScreen(),
          ),
          GoRoute(
            path: 'cau-do/choi',
            builder: (context, state) {
              final q = state.uri.queryParameters;
              final mode = switch (q['mode']) {
                'daily' => QuizMode.daily,
                'period' => QuizMode.byPeriod,
                'era' => QuizMode.byEra,
                _ => QuizMode.random,
              };
              return QuizPlayScreen(
                mode: mode,
                seed: int.tryParse(q['seed'] ?? '') ?? 0,
                periodId: q['period'],
                eraSlug: q['era'],
              );
            },
          ),
        ],
      ),
      // The images & content disclaimer (Sảnh, About, the ⓘ by a caption).
      GoRoute(
        path: kDisclaimerRoute,
        builder: (context, state) => const DisclaimerScreen(),
      ),
      // Chào cờ — online flag salute (waving flag + Tiến quân ca + lyrics).
      GoRoute(
        path: '/chao-co',
        builder: (context, state) => const ChaoCoScreen(),
      ),
      // Any event by id alone (street map, quiz, a link that knows no era). An
      // event inside an era is redirected to its own route *here*, before a
      // location exists for the telemetry observer to log — so nothing is
      // double-counted; only a standalone event reaches the screen.
      GoRoute(
        path: '/su-kien/:id',
        redirect: (context, state) async {
          final id = state.pathParameters['id']!;
          try {
            final found =
                await ref.read(contentRepositoryProvider).findEvent(id);
            final era = found?.era;
            if (era != null) return '/era/${era.slug}/event/$id';
          } catch (_) {
            // Content unreadable: fall through to the screen, which shows it.
          }
          return null;
        },
        builder: (context, state) =>
            StandaloneEventScreen(eventId: state.pathParameters['id']!),
      ),
      // A standalone person (Cycle R): on no era's roster, so no era route
      // exists for them. A rostered person is sent on to their home era's
      // figure page *here*, before a location exists to be logged.
      GoRoute(
        path: '/nhan-vat/:id',
        redirect: (context, state) async {
          final id = state.pathParameters['id']!;
          try {
            final home = await ref.read(homeEraSlugsProvider.future);
            final slug = home[id];
            if (slug != null) return '/era/$slug/figure/$id';
          } catch (_) {
            // Content unreadable: fall through to the screen, which shows it.
          }
          return null;
        },
        builder: (context, state) =>
            StandaloneCharacterScreen(figureId: state.pathParameters['id']!),
      ),
      // "Hôm nay" (Cycle S): today's pick, resolved on the device and sent on
      // to its own page — an in-era event or person to its era route, a
      // standalone one to its own. Like the two routes above it never has a
      // screen of its own, so the page it lands on is what gets logged.
      GoRoute(
        path: '/hom-nay',
        redirect: (context, state) async {
          try {
            final ctx = await ref.read(todayContextProvider.future);
            final item = ctx.pickFor(DateTime.now());
            if (item != null) {
              switch (item.kind) {
                case TodayKind.event:
                  final found =
                      await ref.read(contentRepositoryProvider).findEvent(item.id);
                  final era = found?.era;
                  return era != null
                      ? '/era/${era.slug}/event/${item.id}'
                      : '/su-kien/${item.id}';
                case TodayKind.person:
                  final home = await ref.read(homeEraSlugsProvider.future);
                  final slug = home[item.id];
                  return slug != null
                      ? '/era/$slug/figure/${item.id}'
                      : '/nhan-vat/${item.id}';
              }
            }
          } catch (_) {
            // Content unreadable: the Sảnh is a calm place to land.
          }
          return '/sanh';
        },
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/era/:slug',
        builder: (context, state) =>
            EraHubScreen(slug: state.pathParameters['slug']!),
        routes: <RouteBase>[
          GoRoute(
            path: 'timeline',
            builder: (context, state) =>
                EraTimelineScreen(slug: state.pathParameters['slug']!),
          ),
          GoRoute(
            path: 'event/:id',
            builder: (context, state) => EventDetailScreen(
              slug: state.pathParameters['slug']!,
              eventId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: 'figure/:id',
            builder: (context, state) => CharacterDetailScreen(
              slug: state.pathParameters['slug']!,
              figureId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
    ],
  );
});

/// The clock `screen_leave` durations are measured with — a seam for tests.
final telemetryClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Logs a `screen_view` on every navigation — see route_telemetry.dart.
/// A plain [Provider] (not autoDispose): one observer for the app's whole
/// lifetime, matching [routerProvider]'s own lifetime.
final routeTelemetryObserverProvider = Provider<RouteTelemetryObserver>((ref) {
  final observer = RouteTelemetryObserver(
      ref.watch(routerProvider), ref.watch(telemetryProvider),
      clock: ref.watch(telemetryClockProvider));
  ref.onDispose(observer.dispose);
  return observer;
});

/// Records which people, events and eras the reader has opened, for the street
/// map's discovered streets — see visit_store.dart. Kept alive like the
/// telemetry observer.
final visitRecorderProvider = Provider<VisitRecorder>((ref) {
  final recorder = VisitRecorder(ref.watch(routerProvider), (key) {
    ref.read(visitedProvider.notifier).record(key).catchError(
          (Object e, StackTrace s) =>
              reportNonFatal(e, s, reason: 'VisitRecorder.record'),
        );
  });
  ref.onDispose(recorder.dispose);
  return recorder;
});
