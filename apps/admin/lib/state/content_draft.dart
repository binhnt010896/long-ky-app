import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_providers.dart';
import '../api/cms_api_client.dart';

/// One `GET /content` load — every `content/**/*.json` file at `main`'s
/// head, plus [baseSha]. [files] starts equal to [baseline] and diverges as
/// the admin edits; [pendingChanges] is exactly what `POST /commit` needs.
class ContentDraft {
  const ContentDraft({required this.baseSha, required this.baseline, required this.files});

  factory ContentDraft.fromLoad(ContentAtHead loaded) =>
      ContentDraft(baseSha: loaded.sha, baseline: loaded.files, files: loaded.files);

  final String baseSha;
  final Map<String, String> baseline;
  final Map<String, String> files;

  bool get isDirty => pendingChanges.isNotEmpty;

  Map<String, String> get pendingChanges => {
    for (final entry in files.entries)
      if (baseline[entry.key] != entry.value) entry.key: entry.value,
  };

  ContentDraft withFile(String path, String text) =>
      ContentDraft(baseSha: baseSha, baseline: baseline, files: {...files, path: text});

  ContentDraft settled(String newSha) =>
      ContentDraft(baseSha: newSha, baseline: files, files: files);

  Map<String, String> get eraFiles => {
    for (final entry in files.entries)
      if (entry.key.startsWith('content/eras/') && entry.key.endsWith('.json'))
        entry.key.replaceFirst('content/eras/', ''): entry.value,
  };

  String get peopleJson => files['content/people.json']!;
  String get periodsJson => files['content/periods.json']!;
  String get indexJson => files['content/index.json']!;
  String get eraSchemaJson => files['content/era.schema.json']!;
  String get peopleSchemaJson => files['content/people.schema.json']!;
  String get periodSchemaJson => files['content/period.schema.json']!;

  ContentValidationResult validate() => ContentValidator.validateAll(
    eraSchemaJson: eraSchemaJson,
    peopleSchemaJson: peopleSchemaJson,
    periodSchemaJson: periodSchemaJson,
    eraFiles: eraFiles,
    peopleJson: peopleJson,
    periodsJson: periodsJson,
    indexJson: indexJson,
  );
}

class ContentDraftController extends AsyncNotifier<ContentDraft> {
  @override
  Future<ContentDraft> build() async {
    final loaded = await ref.read(cmsApiClientProvider).getContent();
    return ContentDraft.fromLoad(loaded);
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final loaded = await ref.read(cmsApiClientProvider).getContent();
      return ContentDraft.fromLoad(loaded);
    });
  }

  /// Formats [text] to canonical layout before staging it, so a save
  /// always diffs as just the field that changed — the same rule
  /// `tool/format_content.dart` enforces in CI.
  void editFile(String path, String text) {
    final current = state.valueOrNull;
    if (current == null) return;
    final canonical = ContentFormatter.reformat(text);
    state = AsyncData(current.withFile(path, canonical));
  }

  /// Commits every pending edit as one atomic commit, then folds the new
  /// head sha back into the draft as its new baseline. Throws
  /// [CommitConflictException] if `main` moved — the caller should show
  /// that and offer [reload], not retry blindly.
  Future<void> commit(String message) async {
    final current = state.requireValue;
    if (!current.isDirty) return;
    final newSha = await ref
        .read(cmsApiClientProvider)
        .commit(baseSha: current.baseSha, files: current.pendingChanges, message: message);
    state = AsyncData(current.settled(newSha));
  }
}

final contentDraftProvider = AsyncNotifierProvider<ContentDraftController, ContentDraft>(
  ContentDraftController.new,
);
