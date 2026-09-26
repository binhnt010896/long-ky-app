import 'dart:ui' show PlatformDispatcher;

import 'package:core_content/core_content.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'state/content_sync.dart';
import 'state/providers.dart';
import 'telemetry/firebase_telemetry.dart';
import 'telemetry/telemetry.dart';
import 'telemetry/telemetry_settings.dart';
import 'theme/content_assets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Android release only — see telemetry/telemetry.dart and
  // firebase_options.dart (web/iOS deliberately unconfigured). Constructed
  // once here and handed to the widget tree below via an override, so
  // main()'s error handlers and every screen's ref.watch(telemetryProvider)
  // are the exact same object.
  final Telemetry telemetry;
  if (!kIsWeb && kReleaseMode) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    telemetry = FirebaseTelemetry();
    // Uncaught errors — fatal by definition, reported with no PII.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      telemetry.recordError(details.exception, details.stack ?? StackTrace.empty,
          reason: 'FlutterError.onError', fatal: true);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      telemetry.recordError(error, stack, reason: 'PlatformDispatcher.onError', fatal: true);
      return true;
    };
  } else {
    telemetry = const NoopTelemetry();
  }
  // The Về Long Ký switch, applied before the first event goes out.
  final analyticsEnabled = await FileTelemetrySettingsStore().load();
  await telemetry.setEnabled(analyticsEnabled);

  await ContentMedia.load();

  // Resume any previously-downloaded content pack (validated fresh — see
  // ContentSync.startup) layered over the bundled content, so a phone that
  // already has a newer pack opens straight to it rather than the baseline.
  final (source: ota, activeVersion: activeVersion) =
      await ContentSync.startup(BundledContentSource(
    manifestPath: 'assets/content/index.json',
    eraDir: 'assets/content/eras',
    peoplePath: 'assets/content/people.json',
    periodsPath: 'assets/content/periods.json',
  ));
  // A pack downloaded in the background during a previous session only takes
  // effect now, at this launch — the splash logs the other case (a pack that
  // arrives and is adopted live, while the splash is still up).
  if (activeVersion != await ContentSync.bundledVersion()) {
    telemetry.event('content_pack_adopted',
        <String, Object>{'version': activeVersion, 'at': 'next_launch'});
  }

  runApp(ProviderScope(
    overrides: <Override>[
      contentRepositoryProvider.overrideWithValue(ContentRepository(ota)),
      activeContentVersionProvider.overrideWith((ref) => activeVersion),
      // The exact instance whose error handlers are already wired above, and
      // whose enabled-state main.dart just applied — telemetryEnabledProvider
      // independently reloads the same on-disk setting for its own state.
      telemetryProvider.overrideWithValue(telemetry),
    ],
    child: const VietSuApp(),
  ));
}
