import 'package:core_content/core_content.dart';

/// The app's bundled baseline content — the one place its asset paths are
/// spelled out. Asset keys match the pubspec: `assets/content/…`, a symlink to
/// the canonical repo-root `content/`.
///
/// `main.dart` (which hands it to `ContentSync.startup`) and
/// `contentRepositoryProvider` both need it; building it in two places let one
/// of them miss a path once (Cycle N's `events.json`), and every screen that
/// loaded an era then failed. Both now call this.
BundledContentSource appBundledContent() => BundledContentSource(
      manifestPath: 'assets/content/index.json',
      eraDir: 'assets/content/eras',
      peoplePath: 'assets/content/people.json',
      periodsPath: 'assets/content/periods.json',
      eventsPath: 'assets/content/events.json',
    );
