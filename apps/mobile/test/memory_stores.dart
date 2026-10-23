import 'package:viet_su/state/narration_store.dart';
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
