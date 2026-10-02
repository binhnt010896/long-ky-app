import 'package:core_content/core_content.dart';
import 'package:core_domain/core_domain.dart';
import 'package:experience/experience.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../telemetry/telemetry.dart';
import '../telemetry/telemetry_settings.dart';
import 'bundled_content.dart';
import 'lang_store.dart';

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
  return ContentRepository.withOta(appBundledContent());
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

/// Events no era lists (Cycle N), in source order. Empty until one is
/// authored. Drives the standalone event page, the global timeline's "Sự kiện
/// riêng" nodes, the quiz, and the Character page's "Cũng xuất hiện trong".
final standaloneEventsProvider = FutureProvider<List<HistoryEvent>>((ref) {
  return ref.watch(contentRepositoryProvider).loadStandaloneEvents();
});

/// The event with [id] and, if it sits in an era, that era — or null when no
/// such event exists. Drives `/su-kien/:id`.
final eventLocationProvider =
    FutureProvider.family<EventLocation?, String>((ref, id) {
  return ref.watch(contentRepositoryProvider).findEvent(id);
});

/// The people registry (`content/people.json`).
final peopleProvider = FutureProvider<PeopleRegistry>((ref) {
  return ref.watch(contentRepositoryProvider).loadPeople();
});

/// For each person on at least one era's roster, the slug of their *home era*:
/// the earliest era (by [Era.order]) that lists them. A standalone event has
/// no era of its own, so its figure chips open the figure's page in this era —
/// the same rule the street map uses.
final homeEraSlugsProvider = FutureProvider<Map<String, String>>((ref) async {
  final eras = await ref.watch(erasProvider.future);
  final home = <String, String>{};
  for (final era in eras) {
    for (final c in era.characters) {
      home.putIfAbsent(c.id, () => era.slug);
    }
  }
  return home;
});

/// One era by slug (cached by the repository). Drives Hub / Timeline / Detail.
final eraProvider = FutureProvider.family<Era, String>((ref, slug) {
  return ref.watch(contentRepositoryProvider).loadEra(slug);
});

/// The active reading language. Vietnamese is canonical and is the default
/// until [FileLangStore] has loaded a saved choice — main.dart overrides this
/// provider's initial value with that load's result before the first frame.
/// The Sảnh's [LangToggle] flips this (and persists the choice via
/// [langStoreProvider]); every language-aware screen reads it.
final langProvider = StateProvider<Lang>((ref) => Lang.vi);

/// Persists the VI/EN choice — see `state/lang_store.dart`.
final langStoreProvider = Provider<LangStore>((ref) => FileLangStore());

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

/// The "Gửi thống kê ẩn danh" store — see telemetry/telemetry_settings.dart.
final telemetrySettingsStoreProvider =
    Provider<TelemetrySettingsStore>((ref) => FileTelemetrySettingsStore());

/// Whether analytics/crash collection is enabled — default **on**, no
/// first-run prompt. The Về Long Ký switch reads and writes this; main.dart
/// applies it to [Telemetry] on startup and whenever it changes.
final telemetryEnabledProvider =
    AsyncNotifierProvider<TelemetryEnabledNotifier, bool>(
        TelemetryEnabledNotifier.new);

class TelemetryEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.watch(telemetrySettingsStoreProvider).load();

  Future<void> setEnabled(bool enabled) async {
    state = AsyncData<bool>(enabled);
    await ref.read(telemetrySettingsStoreProvider).setEnabled(enabled);
    await ref.read(telemetryProvider).setEnabled(enabled);
  }
}

/// Opens a web address in the phone's browser. A seam so tests never launch
/// anything; returns false when nothing could open it.
final urlOpenerProvider = Provider<Future<bool> Function(Uri)>(
    (ref) => (uri) => launchUrl(uri, mode: LaunchMode.externalApplication));
