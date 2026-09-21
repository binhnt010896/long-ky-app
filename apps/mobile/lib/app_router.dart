import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/chao_co/chao_co_screen.dart';
import 'screens/character/character_detail_screen.dart';
import 'screens/era/era_hub_screen.dart';
import 'screens/era/era_timeline_screen.dart';
import 'screens/event/event_detail_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/prototype/territory_map_demo_screen.dart';
import 'screens/timeline/global_timeline_screen.dart';

/// App routes.
///  - `/`                       Home — the vertical era stack.
///  - `/timeline`               Global Timeline — every era's events in order
///                              (pushed from Home's corner affordance).
///  - `/era/:slug`              Era Hub — parallax hero + facets.
///  - `/era/:slug/timeline`     Era Timeline — this era's events.
///  - `/era/:slug/event/:id`    Event Detail — hero, body, pull-quote, citation.
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
      // Chào cờ — online flag salute (waving flag + Tiến quân ca + lyrics).
      GoRoute(
        path: '/chao-co',
        builder: (context, state) => const ChaoCoScreen(),
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
