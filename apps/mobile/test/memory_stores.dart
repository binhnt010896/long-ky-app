import 'package:viet_su/state/narration_store.dart';
import 'package:viet_su/state/reminder_service.dart';
import 'package:viet_su/state/today_store.dart';
import 'package:viet_su/state/visit_store.dart';

/// In-memory stand-ins for the file-backed stores, so widget tests never touch
/// `path_provider` (unmocked there).
class MemoryVisitStore implements VisitStore {
  MemoryVisitStore([this.data = const VisitData(backfilled: true)]);
  VisitData data;
  int saves = 0;

  @override
  Future<VisitData> load() async => data;

  @override
  Future<void> save(VisitData d) async {
    data = d;
    saves++;
  }
}

class MemoryNarrationStore implements NarrationStore {
  MemoryNarrationStore([Set<String> heard = const <String>{}])
      : prefs = NarrationPrefs(heard: heard);
  NarrationPrefs prefs;

  @override
  Future<NarrationPrefs> load() async => prefs;

  @override
  Future<void> save(NarrationPrefs p) async => prefs = p;
}

/// In-memory "Hôm nay" preferences.
class MemoryTodayStore implements TodayStore {
  MemoryTodayStore([this.prefs = const TodayPrefs()]);
  TodayPrefs prefs;

  @override
  Future<TodayPrefs> load() async => prefs;

  @override
  Future<void> save(TodayPrefs p) async => prefs = p;
}

/// A recording stand-in for the device's notifications.
class FakeReminderScheduler implements ReminderScheduler {
  FakeReminderScheduler({this.grant = true, this.launchedByTap = false});

  /// What the OS answers when permission is requested.
  bool grant;
  bool launchedByTap;
  int permissionRequests = 0;
  int cancels = 0;
  int inits = 0;
  void Function()? onOpen;
  List<ReminderEntry> scheduled = const <ReminderEntry>[];
  final List<List<ReminderEntry>> history = <List<ReminderEntry>>[];

  @override
  Future<void> init(void Function() onOpen) async {
    inits++;
    this.onOpen = onOpen;
  }

  @override
  Future<bool> launchedByReminder() async => launchedByTap;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return grant;
  }

  @override
  Future<void> replaceAll(List<ReminderEntry> entries) async {
    scheduled = entries;
    history.add(entries);
  }

  @override
  Future<void> cancelAll() async {
    cancels++;
    scheduled = const <ReminderEntry>[];
  }
}
