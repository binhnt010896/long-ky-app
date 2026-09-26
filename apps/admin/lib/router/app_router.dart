import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_providers.dart';
import '../screens/content_tree_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/era_editor_screen.dart';
import '../screens/media_library_screen.dart';
import '../screens/people_screen.dart';
import '../screens/publish_screen.dart';
import '../screens/shell_screen.dart';
import '../screens/sign_in_screen.dart';

/// Notifies GoRouter's redirect logic whenever Firebase's auth state
/// changes — GoRouter itself has no async-stream awareness.
class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefreshListenable(ref);
  return GoRouter(
    refreshListenable: refresh,
    initialLocation: '/',
    redirect: (context, state) {
      final signedIn = ref.read(authStateProvider).valueOrNull != null;
      final onSignIn = state.matchedLocation == '/sign-in';
      if (!signedIn && !onSignIn) return '/sign-in';
      if (signedIn && onSignIn) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/sign-in', builder: (context, state) => const SignInScreen()),
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
          GoRoute(path: '/eras', builder: (context, state) => const ContentTreeScreen()),
          GoRoute(
            path: '/eras/:slug',
            builder: (context, state) => EraEditorScreen(slug: state.pathParameters['slug']!),
          ),
          GoRoute(path: '/people', builder: (context, state) => const PeopleScreen()),
          GoRoute(
            path: '/media',
            builder: (context, state) =>
                MediaLibraryScreen(focusPath: state.uri.queryParameters['focus']),
          ),
          GoRoute(path: '/publish', builder: (context, state) => const PublishScreen()),
        ],
      ),
    ],
  );
});
