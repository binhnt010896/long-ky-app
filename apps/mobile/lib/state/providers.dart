import 'package:core_content/core_content.dart';
import 'package:core_domain/core_domain.dart';
import 'package:experience/experience.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The active experience tier.
///
/// A runtime decision (device capability probe / user override / trailer build).
/// Overridden in tests and, later, set by a real probe near app start. Default
/// is flagship; a genuine probe lands with the Android API-29 + Vulkan check.
final tierProvider = Provider<ExperienceTier>((ref) => ExperienceTier.flagship);

/// The content repository, reading bundled assets behind the OTA seam.
///
/// Asset keys match the app pubspec: `assets/content/…` (a symlink to the
/// canonical repo-root `content/`).
final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  return ContentRepository.withOta(
    BundledContentSource(
      manifestPath: 'assets/content/index.json',
      eraDir: 'assets/content/eras',
      peoplePath: 'assets/content/people.json',
      periodsPath: 'assets/content/periods.json',
    ),
  );
});

/// All eras, sorted by [Era.order]. Drives the global timeline.
final erasProvider = FutureProvider<List<Era>>((ref) {
  return ref.watch(contentRepositoryProvider).loadAllEras();
});

/// Eras grouped into dynasties/periods, in order. Drives the Home dynasty hub
/// (vertical = dynasty, horizontal = the eras within it).
final dynastiesProvider = FutureProvider<List<Dynasty>>((ref) {
  return ref.watch(contentRepositoryProvider).loadDynasties();
});

/// The period registry (`content/periods.json`) — used to group the global
/// timeline under dynasty headers.
final periodsProvider = FutureProvider<PeriodRegistry>((ref) {
  return ref.watch(contentRepositoryProvider).loadPeriods();
});

/// One era by slug (cached by the repository). Drives Hub / Timeline / Detail.
final eraProvider = FutureProvider.family<Era, String>((ref, slug) {
  return ref.watch(contentRepositoryProvider).loadEra(slug);
});

/// The active reading language. Vietnamese is canonical; the VI/EN toggle in the
/// Era Hub flips this, and Hub / Timeline / Detail read it.
final langProvider = StateProvider<Lang>((ref) => Lang.vi);

/// Today's date, read once per build. Overridden in tests to pin the day.
final todayProvider = Provider<DateTime>((ref) => DateTime.now());

/// The national-day label for [day] (VI, slash dates), or null on other days.
String? nationalDayOn(DateTime day) => switch ((day.day, day.month)) {
      (30, 4) => '30/4 · Thống nhất đất nước',
      (2, 9) => '2/9 · Quốc khánh',
      _ => null,
    };

/// Remembered scroll position of the Home dynasty hub, so returning to Home
/// restores where the user left off. Needed because the hub's page views hold
/// their index in widget state that is destroyed when a dynasty page scrolls
/// off-screen (inner era pager) or when Home is rebuilt by a stack-replacing
/// navigation (outer dynasty pager).
///
/// [hubDynastyIndexProvider] is the active dynasty (vertical) page;
/// [hubEraIndexProvider] maps a period id to its active era (horizontal) page.
final hubDynastyIndexProvider = StateProvider<int>((ref) => 0);
final hubEraIndexProvider =
    StateProvider<Map<String, int>>((ref) => <String, int>{});
