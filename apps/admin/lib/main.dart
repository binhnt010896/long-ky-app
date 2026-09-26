import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'router/app_router.dart';
import 'state/theme_prefs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: AdminApp()));
}

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final prefs = ref.watch(themePrefsProvider).valueOrNull;
    final accent = prefs?.accent ?? CmsAccent.slate;

    return MaterialApp.router(
      title: 'Long Ký CMS',
      themeMode: prefs?.themeMode ?? ThemeMode.system,
      theme: ThemeData(colorScheme: _schemeFor(accent.color, Brightness.light)),
      darkTheme: ThemeData(colorScheme: _schemeFor(accent.color, Brightness.dark)),
      routerConfig: router,
    );
  }
}

/// Deliberately NOT [ColorScheme.fromSeed] — its HCT-based tonal palette
/// derives every surface/background/container tone from the seed's hue,
/// and for a desaturated seed (slate, the default) that derivation drifts
/// toward an unrelated, more saturated hue: the whole app read pink/red
/// even with a blue-gray seed, which is exactly what the user flagged.
/// Building the scheme by hand keeps chrome genuinely neutral gray in
/// both themes; only `primary`/`secondary` (buttons, selection, links)
/// take the picked accent colour.
ColorScheme _schemeFor(Color accent, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final primary = dark ? Color.lerp(accent, Colors.white, 0.35)! : accent;
  final onPrimary = primary.computeLuminance() > 0.4 ? Colors.black : Colors.white;

  return dark
      ? ColorScheme.dark(
          primary: primary,
          onPrimary: onPrimary,
          secondary: primary,
          surface: const Color(0xFF17181A),
          onSurface: const Color(0xFFE3E3E3),
          surfaceContainerHighest: const Color(0xFF2A2B2E),
          error: const Color(0xFFCF6679),
        )
      : ColorScheme.light(
          primary: primary,
          onPrimary: onPrimary,
          secondary: primary,
          surface: const Color(0xFFFAFAFA),
          onSurface: const Color(0xFF1B1B1B),
          surfaceContainerHighest: const Color(0xFFE7E7E7),
          error: const Color(0xFFB3261E),
        );
}
