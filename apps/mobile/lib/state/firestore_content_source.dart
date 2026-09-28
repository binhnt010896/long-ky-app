import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_content/core_content.dart';

/// A [ContentSource] that can also report when it's changed — what
/// [FirestoreContentSync] needs, kept abstract so tests can fake it without
/// a real Firestore backend. [FirestoreContentSource] is the real one.
abstract interface class LiveContentSource implements ContentSource {
  /// Fires whenever the underlying content changes. Never throws, never
  /// closes on its own (see [FirestoreContentSource.changes]'s doc comment).
  Stream<void> changes();
}

/// Era/people/periods text read live from Firestore (Cycle K5) — set as
/// [OtaContentSource.liveOverlay] so an edit published from the CMS reaches
/// an already-open app in about a second, instead of the R2-pack OTA path's
/// two-cold-starts delay. Media (images/video, and the manifest that maps a
/// content path to its served URL) is unaffected by this — still delivered
/// entirely through the existing R2-pack OTA path
/// (`apps/mobile/lib/state/content_sync.dart`), so a replaced image still
/// needs the pack-refresh timing that path already has. Folding the media
/// manifest into this live path too is a natural next step, not done here.
///
/// Every read here is short-timeout and catches its own errors as
/// [ContentSourceException] — this must never hang or throw anything else,
/// since [OtaContentSource] relies on exactly that to fall through to the
/// downloaded pack or the bundled baseline when Firestore isn't reachable
/// (not yet enabled for this project, offline, etc.). That fallback is what
/// makes it safe to wire this in unconditionally, before Firestore is even
/// turned on for the project.
class FirestoreContentSource implements LiveContentSource {
  FirestoreContentSource({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const _timeout = Duration(seconds: 3);

  CollectionReference<Map<String, dynamic>> get _eras => _db.collection('eras');
  DocumentReference<Map<String, dynamic>> get _people =>
      _db.collection('singletons').doc('people');
  DocumentReference<Map<String, dynamic>> get _periods =>
      _db.collection('singletons').doc('periods');

  @override
  Future<List<String>> availableSlugs() async {
    try {
      final snap = await _eras.get().timeout(_timeout);
      return snap.docs.map((d) => d.id).toList();
    } catch (e) {
      throw ContentSourceException('Firestore eras list unavailable: $e');
    }
  }

  @override
  Future<String> loadEraJson(String slug) async {
    try {
      final snap = await _eras.doc(slug).get().timeout(_timeout);
      final json = snap.data()?['json'] as String?;
      if (json == null) {
        throw ContentSourceException('era not in Firestore: $slug');
      }
      return json;
    } on ContentSourceException {
      rethrow;
    } catch (e) {
      throw ContentSourceException('Firestore era unavailable: $slug ($e)');
    }
  }

  @override
  Future<String> loadPeopleJson() => _singleton(_people, 'people');

  @override
  Future<String> loadPeriodsJson() => _singleton(_periods, 'periods');

  Future<String> _singleton(
      DocumentReference<Map<String, dynamic>> ref, String name) async {
    try {
      final snap = await ref.get().timeout(_timeout);
      final json = snap.data()?['json'] as String?;
      if (json == null) {
        throw ContentSourceException('$name not in Firestore');
      }
      return json;
    } on ContentSourceException {
      rethrow;
    } catch (e) {
      throw ContentSourceException('Firestore $name unavailable: $e');
    }
  }

  /// Fires whenever any era, people or periods document changes — the
  /// live-update signal [ContentSwapGate] listens to. Never closes on its
  /// own: a snapshot-stream error (e.g. a network blip) is swallowed rather
  /// than silencing future updates, since there is no one to restart the
  /// listener otherwise.
  @override
  Stream<void> changes() {
    final controller = StreamController<void>.broadcast();
    late final List<StreamSubscription<void>> subs;
    void emit(void _) {
      if (!controller.isClosed) controller.add(null);
    }

    void onError(Object error, StackTrace stackTrace) {
      // Swallowed — see the doc comment above.
    }

    controller.onListen = () {
      subs = [
        _eras.snapshots().listen(emit, onError: onError),
        _people.snapshots().listen(emit, onError: onError),
        _periods.snapshots().listen(emit, onError: onError),
      ];
    };
    controller.onCancel = () async {
      for (final s in subs) {
        await s.cancel();
      }
    };
    return controller.stream;
  }
}
