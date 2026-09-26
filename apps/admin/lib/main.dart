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

  // The unnamed ColorScheme.light/dark constructors bake in fixed Material
  // defaults for every field not passed explicitly — onSurfaceVariant (what
  // an unstyled IconButton's glyph actually uses) among them. Leaving it
  // unset made every plain icon button in the app (Appearance, sign-out,
  // every delete/reorder icon in the tree and media library) render at
  // near-zero contrast against the custom surface, visible only on hover.
  // Every field an unstyled control might read now gets a deliberate,
  // contrast-checked value instead of an inherited default.
  return dark
      ? ColorScheme.dark(
          primary: primary,
          onPrimary: onPrimary,
          secondary: primary,
          onSecondary: onPrimary,
          surface: const Color(0xFF17181A),
          onSurface: const Color(0xFFE3E3E3),
          onSurfaceVariant: const Color(0xFFC4C6C8),
          surfaceContainerHighest: const Color(0xFF2A2B2E),
          outline: const Color(0xFF8A8D91),
          outlineVariant: const Color(0xFF444649),
          error: const Color(0xFFCF6679),
          onError: Colors.black,
        )
      : ColorScheme.light(
          primary: primary,
          onPrimary: onPrimary,
          secondary: primary,
          onSecondary: onPrimary,
          surface: const Color(0xFFFAFAFA),
          onSurface: const Color(0xFF1B1B1B),
          onSurfaceVariant: const Color(0xFF44474A),
          surfaceContainerHighest: const Color(0xFFE7E7E7),
          outline: const Color(0xFF74777A),
          outlineVariant: const Color(0xFFC4C6C8),
          error: const Color(0xFFB3261E),
          onError: Colors.white,
        );
}
