import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../telemetry/telemetry.dart';
import 'narration_controller.dart';
import 'providers.dart';
import 'visit_store.dart';

/// Quiz unlocks allowed a day. Every quiz on a hidden page ends in an unlock
/// (a wrong answer is tried again), so without a cap one sitting would open
/// everything and the daily gift would stop mattering.
const int kQuizUnlocksPerDay = 3;

/// Every this many gifts opened, the daily reminder is offered again while it
/// is off.
const int kGiftReminderEvery = 5;

/// Everything the unlock game remembers, on this device only.
class UnlockData {
  const UnlockData({
    this.unlocked = const <String>{},
    this.giftDate,
    this.giftKey,
    this.streak = const StreakState(),
    this.quizDay,
    this.quizCount = 0,
    this.migrated = false,
    this.installSeed = 0,
    this.lostStreak = 0,
    this.giftClaims = 0,
  });

  /// [VisitKey]s whose art has been opened.
  final Set<String> unlocked;

  /// The day the gift was opened, and what it was (null once all is open).
  final String? giftDate;
  final String? giftKey;

  final StreakState streak;

  /// The day [quizCount] counts, and the quiz unlocks made on it.
  final String? quizDay;
  final int quizCount;

  /// Pages opened before this feature existed have been unlocked.
  final bool migrated;

  /// Makes the daily gift differ between installs.
  final int installSeed;

  /// A streak just lost and not yet told to the reader (0 = nothing to say).
  final int lostStreak;

  /// How many daily gifts have been opened, ever. Every [kGiftReminderEvery]th
  /// one offers the daily reminder again, if it is still off.
  final int giftClaims;

  bool giftOpenedOn(DateTime day) => giftDate == dayKey(day);

  int quizUnlocksOn(DateTime day) => quizDay == dayKey(day) ? quizCount : 0;

  UnlockData copyWith({
    Set<String>? unlocked,
    String? giftDate,
    String? giftKey,
    StreakState? streak,
    String? quizDay,
    int? quizCount,
    bool? migrated,
    int? installSeed,
    int? lostStreak,
    int? giftClaims,
  }) =>
      UnlockData(
        unlocked: unlocked ?? this.unlocked,
        giftDate: giftDate ?? this.giftDate,
        giftKey: giftKey ?? this.giftKey,
        streak: streak ?? this.streak,
        quizDay: quizDay ?? this.quizDay,
        quizCount: quizCount ?? this.quizCount,
        migrated: migrated ?? this.migrated,
        installSeed: installSeed ?? this.installSeed,
        lostStreak: lostStreak ?? this.lostStreak,
        giftClaims: giftClaims ?? this.giftClaims,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'unlocked': unlocked.toList()..sort(),
        if (giftDate != null) 'giftDate': giftDate,
        if (giftKey != null) 'giftKey': giftKey,
        'streak': <String, dynamic>{
          'current': streak.current,
          'best': streak.best,
          if (streak.lastDay != null) 'lastDay': streak.lastDay,
          'freezes': streak.freezes,
        },
        if (quizDay != null) 'quizDay': quizDay,
        'quizCount': quizCount,
        'migrated': migrated,
        'installSeed': installSeed,
        'lostStreak': lostStreak,
        'giftClaims': giftClaims,
      };

  /// Anything unreadable falls back to the default for that field.
  static UnlockData fromJson(Map<String, dynamic> raw) {
    int nonNeg(Object? v) => v is int && v >= 0 ? v : 0;
    String? str(Object? v) => v is String ? v : null;
    final unlocked = raw['unlocked'];
    final s = raw['streak'];
    final streak = s is Map<String, dynamic>
        ? StreakState(
            current: nonNeg(s['current']),
            best: nonNeg(s['best']),
            lastDay: str(s['lastDay']),
            freezes: min(nonNeg(s['freezes']), kMaxFreezes),
          )
        : const StreakState();
    return UnlockData(
      unlocked:
          unlocked is List ? unlocked.whereType<String>().toSet() : <String>{},
      giftDate: str(raw['giftDate']),
      giftKey: str(raw['giftKey']),
      streak: streak,
      quizDay: str(raw['quizDay']),
      quizCount: nonNeg(raw['quizCount']),
      migrated: raw['migrated'] == true,
      installSeed: nonNeg(raw['installSeed']),
      lostStreak: nonNeg(raw['lostStreak']),
      giftClaims: nonNeg(raw['giftClaims']),
    );
  }
}

/// The unlock persistence seam — file-backed in the app, in-memory in tests.
abstract class UnlockStore {
  Future<UnlockData> load();
  Future<void> save(UnlockData data);
}

/// Same on-disk pattern as the other small stores (atomic write, defaults on a
/// bad file); on web it keeps the data in memory for the session only.
class FileUnlockStore implements UnlockStore {
  UnlockData? _cached;

  static Future<File?> _file() async {
    if (kIsWeb) return null;
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/unlocks.json');
  }

  @override
  Future<UnlockData> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    try {
      final file = await _file();
      if (file == null || !file.existsSync()) return _cached = const UnlockData();
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map<String, dynamic>) return _cached = const UnlockData();
      return _cached = UnlockData.fromJson(raw);
    } catch (e, s) {
      reportNonFatal(e, s, reason: 'FileUnlockStore.load');
      return _cached = const UnlockData();
    }
  }

  @override
  Future<void> save(UnlockData data) async {
    _cached = data;
    try {
      final file = await _file();
      if (file == null) return;
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(jsonEncode(data.toJson()));
      await tmp.rename(file.path);
    } catch (e, s) {
      reportNonFatal(e, s, reason: 'FileUnlockStore.save');
    }
  }
}

final unlockStoreProvider = Provider<UnlockStore>((ref) => FileUnlockStore());

/// "Now", overridable in tests.
final unlockClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Where an unlock came from.
enum UnlockSource { gift, quiz, milestone }

/// What one unlock did, for the reward animation and telemetry.
class UnlockResult {
  const UnlockResult({
    this.key,
    this.source = UnlockSource.gift,
    this.streak,
    this.bonusKey,
    this.capHit = false,
  });

  /// The art opened (null when nothing was left to open, or the cap was hit).
  final String? key;
  final UnlockSource source;

  /// The streak after counting today; null if today was already counted.
  final StreakAdvance? streak;

  /// The extra unlock a 7/30/100-day milestone brought, if any.
  final String? bonusKey;

  /// The day's quiz unlocks were used up; nothing changed.
  final bool capHit;
}

/// The art that starts hidden (see [hiddenArtKeys]), once the eras are loaded.
final hiddenArtProvider = Provider<Set<String>>((ref) {
  final eras = ref.watch(erasProvider).valueOrNull;
  return eras == null ? const <String>{} : hiddenArtKeys(eras);
});

class UnlockNotifier extends AsyncNotifier<UnlockData> {
  @override
  Future<UnlockData> build() async {
    final store = ref.watch(unlockStoreProvider);
    var data = await store.load();
    var dirty = false;
    if (data.installSeed == 0) {
      data = data.copyWith(installSeed: Random().nextInt(1 << 30) + 1);
      dirty = true;
    }
    if (!data.migrated) {
      // Pages the reader has already opened keep their art: taking away a
      // picture someone has seen would feel like a loss.
      final visited = (await ref.read(visitStoreProvider).load()).visited;
      final heard = (await ref.read(narrationStoreProvider).load()).heard;
      data = data.copyWith(
        migrated: true,
        unlocked: <String>{
          ...data.unlocked,
          for (final k in visited)
            if (k.startsWith('person:') || k.startsWith('event:')) k,
          for (final k in heard)
            if (visitKeyFromNarrationKey(k) case final v?)
              if (!v.startsWith('era:')) v,
        },
      );
      dirty = true;
    }
    if (dirty) await store.save(data);
    return data;
  }

  Future<UnlockData> _current() async => state.valueOrNull ?? await future;

  Future<void> _set(UnlockData next) async {
    state = AsyncData(next);
    await ref.read(unlockStoreProvider).save(next);
  }

  DateTime _now() => ref.read(unlockClockProvider)();

  /// Keys still hidden.
  List<String> _remaining(UnlockData d) => [
        for (final k in ref.read(hiddenArtProvider))
          if (!d.unlocked.contains(k)) k,
      ];

  /// Counts today toward the streak. Returns the advance (null if today was
  /// already counted) and the data with the streak applied.
  (UnlockData, StreakAdvance?) _count(UnlockData d, DateTime now) {
    final adv = Streak.advance(d.streak, now);
    if (!adv.counted) return (d, null);
    return (
      d.copyWith(
        streak: adv.state,
        lostStreak: adv.outcome == StreakOutcome.reset && adv.lost > 1
            ? adv.lost
            : d.lostStreak,
      ),
      adv,
    );
  }

  void _logStreak(StreakAdvance? adv) {
    if (adv == null) return;
    final t = ref.read(telemetryProvider);
    if (adv.outcome == StreakOutcome.reset && adv.lost > 0) {
      t.event('streak_reset', <String, Object>{'lost': adv.lost, 'used_freeze': false});
    } else if (adv.outcome == StreakOutcome.usedFreeze) {
      t.event('streak_reset', <String, Object>{'lost': 0, 'used_freeze': true});
    }
    if (adv.milestone != null) {
      t.event('streak_milestone', <String, Object>{'days': adv.milestone!});
    }
  }

  /// Opens today's gift (once a day). The streak counts the day either way, so
  /// once everything is open the gift becomes a congratulation and the streak
  /// still has a way to grow.
  Future<UnlockResult> openGift() async {
    var d = await _current();
    final now = _now();
    if (d.giftOpenedOn(now)) {
      return UnlockResult(key: d.giftKey);
    }
    final key = dailyGiftPick(_remaining(d), now, d.installSeed);
    final (counted, adv) = _count(d, now);
    d = counted.copyWith(
      giftDate: dayKey(now),
      giftKey: key,
      giftClaims: d.giftClaims + 1,
      unlocked: key == null ? null : <String>{...d.unlocked, key},
    );
    final bonus = _applyMilestone(adv, d);
    d = bonus.$1;
    ref.read(lastRewardProvider.notifier).state = UnlockResult(
        key: key, source: UnlockSource.gift, streak: adv, bonusKey: bonus.$2);
    await _set(d);
    ref.read(telemetryProvider).event(
        'gift_open', <String, Object>{'streak': d.streak.current});
    if (key != null) {
      ref.read(telemetryProvider).event('unlock', <String, Object>{
        'source': 'gift',
        'kind': key.startsWith('person:') ? 'person' : 'event',
        'attempts': 0,
      });
    }
    _logStreak(adv);
    return UnlockResult(
        key: key, source: UnlockSource.gift, streak: adv, bonusKey: bonus.$2);
  }

  /// Opens [key] after a right answer. [attempts] is how many taps it took.
  /// Does nothing (and says so) once the day's cap is used.
  Future<UnlockResult> unlockByQuiz(String key, {int attempts = 1}) async {
    var d = await _current();
    final now = _now();
    if (d.unlocked.contains(key)) return const UnlockResult(source: UnlockSource.quiz);
    if (d.quizUnlocksOn(now) >= kQuizUnlocksPerDay) {
      ref.read(telemetryProvider).event('unlock_cap_hit');
      return const UnlockResult(source: UnlockSource.quiz, capHit: true);
    }
    final (counted, adv) = _count(d, now);
    d = counted.copyWith(
      unlocked: <String>{...d.unlocked, key},
      quizDay: dayKey(now),
      quizCount: d.quizUnlocksOn(now) + 1,
    );
    final bonus = _applyMilestone(adv, d);
    d = bonus.$1;
    ref.read(lastRewardProvider.notifier).state = UnlockResult(
        key: key, source: UnlockSource.quiz, streak: adv, bonusKey: bonus.$2);
    await _set(d);
    ref.read(telemetryProvider).event('unlock', <String, Object>{
      'source': 'quiz',
      'kind': key.startsWith('person:') ? 'person' : 'event',
      'attempts': attempts,
    });
    _logStreak(adv);
    return UnlockResult(
        key: key, source: UnlockSource.quiz, streak: adv, bonusKey: bonus.$2);
  }

  /// Counts today for the streak when the reader opens "Hôm nay" — the way a
  /// reader with nothing left to unlock keeps the streak alive.
  Future<UnlockResult?> countToday() async {
    final d = await _current();
    if (_remaining(d).isNotEmpty) return null;
    final (counted, adv) = _count(d, _now());
    if (adv == null) return null;
    await _set(counted);
    _logStreak(adv);
    return UnlockResult(streak: adv);
  }

  /// A 7/30/100-day milestone opens one more piece of art.
  (UnlockData, String?) _applyMilestone(StreakAdvance? adv, UnlockData d) {
    if (adv?.milestone == null) return (d, null);
    final key = dailyGiftPick(
        _remaining(d), _now(), d.installSeed + adv!.milestone!);
    if (key == null) return (d, null);
    ref.read(telemetryProvider).event('unlock', <String, Object>{
      'source': 'milestone',
      'kind': key.startsWith('person:') ? 'person' : 'event',
      'attempts': 0,
    });
    return (d.copyWith(unlocked: <String>{...d.unlocked, key}), key);
  }

  /// The "streak restarted" line has been shown.
  Future<void> dismissLostStreak() async {
    final d = await _current();
    if (d.lostStreak == 0) return;
    await _set(d.copyWith(lostStreak: 0));
  }
}

/// The latest unlock, set just before the art flips, so the page showing it can
/// caption its reveal ("+1 · 35/116", the streak).
final lastRewardProvider = StateProvider<UnlockResult?>((ref) => null);

final unlockProvider =
    AsyncNotifierProvider<UnlockNotifier, UnlockData>(UnlockNotifier.new);

/// Whether the art for [key] is hidden right now. False for anything not in
/// the game (a photographed era, a standalone page, an era cover).
final artHiddenProvider = Provider.family<bool, String>((ref, key) {
  if (!ref.watch(hiddenArtProvider).contains(key)) return false;
  final data = ref.watch(unlockProvider).valueOrNull;
  // Until the saved state is read, assume hidden: showing the picture for a
  // frame and then taking it away would spoil the reveal.
  return data == null || !data.unlocked.contains(key);
});

/// Progress through the hidden art: how many pieces are open of how many.
class UnlockProgress {
  const UnlockProgress(this.opened, this.total);
  final int opened;
  final int total;
}

final unlockProgressProvider = Provider<UnlockProgress>((ref) {
  final hidden = ref.watch(hiddenArtProvider);
  final unlocked = ref.watch(unlockProvider).valueOrNull?.unlocked ?? const <String>{};
  return UnlockProgress(hidden.where(unlocked.contains).length, hidden.length);
});

/// Progress for one era: hidden portraits and event pictures, and how many of
/// each are open.
class EraUnlockProgress {
  const EraUnlockProgress({
    required this.peopleOpened,
    required this.peopleTotal,
    required this.eventsOpened,
    required this.eventsTotal,
  });

  final int peopleOpened, peopleTotal, eventsOpened, eventsTotal;

  int get opened => peopleOpened + eventsOpened;
  int get total => peopleTotal + eventsTotal;
}

EraUnlockProgress eraUnlockProgress(
    Era era, Set<String> hidden, Set<String> unlocked) {
  var po = 0, pt = 0, eo = 0, et = 0;
  for (final c in era.characters) {
    final k = VisitKey.person(c.id);
    if (!hidden.contains(k)) continue;
    pt++;
    if (unlocked.contains(k)) po++;
  }
  for (final e in era.events) {
    final k = VisitKey.event(e.id);
    if (!hidden.contains(k)) continue;
    et++;
    if (unlocked.contains(k)) eo++;
  }
  return EraUnlockProgress(
      peopleOpened: po, peopleTotal: pt, eventsOpened: eo, eventsTotal: et);
}

/// Progress for [era], or null when none of its art is hidden.
final eraUnlockProgressProvider =
    Provider.family<EraUnlockProgress?, String>((ref, slug) {
  final eras = ref.watch(erasProvider).valueOrNull;
  if (eras == null) return null;
  final era = eras.where((e) => e.slug == slug).firstOrNull;
  if (era == null) return null;
  final p = eraUnlockProgress(
    era,
    ref.watch(hiddenArtProvider),
    ref.watch(unlockProvider).valueOrNull?.unlocked ?? const <String>{},
  );
  return p.total == 0 ? null : p;
});
