import 'package:experience/experience.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';

import 'app_router.dart';
import 'screens/splash/splash_gate.dart';
import 'state/providers.dart';

/// Root of the Việt Sử app.
///
/// Resolves the [ExperienceTier] once and threads it to the whole tree via
/// [ExperienceScope] — the single axis screens branch on. Themed with the
/// founding-era palette by default; per-era screens recolour from content.
class VietSuApp extends ConsumerWidget {
  const VietSuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tier = ref.watch(tierProvider);

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    return ExperienceScope(
      tier: tier,
      child: MaterialApp.router(
        title: 'Long Ký',
        debugShowCheckedModeBanner: false,
        theme: VSTheme.build(era: VSEraPalette.hongBangVanLang),
        routerConfig: ref.watch(routerProvider),
        // The Long Ký brand splash overlays the app on launch, then fades.
        builder: (context, child) =>
            SplashGate(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
