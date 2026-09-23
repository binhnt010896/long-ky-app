import 'package:core_content/core_content.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'state/content_sync.dart';
import 'state/providers.dart';
import 'theme/content_assets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  runApp(ProviderScope(
    overrides: <Override>[
      contentRepositoryProvider.overrideWithValue(ContentRepository(ota)),
      activeContentVersionProvider.overrideWith((ref) => activeVersion),
    ],
    child: const VietSuApp(),
  ));
}
