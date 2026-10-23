import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util/narration.dart';
import 'content_draft.dart';

/// The narration jobs file, decoded once per change. Selecting just the JSON
/// text means editing an event doesn't re-parse ~1 MB of scripts.
final narrationIndexProvider = Provider<NarrationIndex>((ref) {
  final json = ref.watch(
    contentDraftProvider.select((d) => d.valueOrNull?.files['content/audio/narration-jobs.json']),
  );
  return NarrationIndex.fromJson(json);
});
