import 'dart:convert';

/// Where the published narration clips live (`tool/publish_narration.sh`
/// uploads `content/audio/vi/**` here).
const cdnAudioBase = 'https://media.binh-nt.dev/audio/vi';

/// One narration job from `content/audio/narration-jobs.json` — the script
/// that was read aloud, and what came back. [kind] is `events`, `people` or
/// `eras`; [slug] is the content id.
class NarrationClip {
  const NarrationClip({
    required this.kind,
    required this.slug,
    required this.text,
    required this.chars,
    required this.hash,
    required this.status,
    this.durationSecs,
  });

  factory NarrationClip.fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String;
    final slash = id.indexOf('/');
    return NarrationClip(
      kind: id.substring(0, slash),
      slug: id.substring(slash + 1),
      text: j['text'] as String? ?? '',
      chars: (j['chars'] as num?)?.toInt() ?? 0,
      hash: j['hash'] as String? ?? '',
      status: j['status'] as String? ?? 'pending',
      durationSecs: (j['durationSecs'] as num?)?.toDouble(),
    );
  }

  final String kind;
  final String slug;
  final String text;
  final int chars;
  final String hash;
  final String status;
  final double? durationSecs;

  /// Generated and recorded; anything else is waiting to be generated.
  bool get isReady => status == 'done';

  /// Cache-busted like the app requests it: `?v=<hash>` changes when the
  /// script (or its speech rules) change and the clip is regenerated.
  String get url => '$cdnAudioBase/$kind/$slug.mp3?v=$hash';

  Duration? get duration =>
      durationSecs == null ? null : Duration(milliseconds: (durationSecs! * 1000).round());
}

/// Every job in the file, looked up by kind + slug.
class NarrationIndex {
  NarrationIndex._(this._byKey);

  factory NarrationIndex.fromJson(String? json) {
    if (json == null || json.trim().isEmpty) return NarrationIndex.empty;
    try {
      final jobs = (jsonDecode(json) as Map<String, dynamic>)['jobs'] as List;
      final byKey = <String, NarrationClip>{};
      for (final j in jobs) {
        final clip = NarrationClip.fromJson((j as Map).cast<String, dynamic>());
        byKey['${clip.kind}/${clip.slug}'] = clip;
      }
      return NarrationIndex._(byKey);
    } catch (_) {
      // A malformed file must never break the editors it decorates.
      return NarrationIndex.empty;
    }
  }

  static final NarrationIndex empty = NarrationIndex._(const {});

  final Map<String, NarrationClip> _byKey;

  int get length => _byKey.length;

  NarrationClip? clipFor(String kind, String slug) => _byKey['$kind/$slug'];

  /// The clip, only when it has actually been generated.
  NarrationClip? readyClipFor(String kind, String slug) {
    final c = clipFor(kind, slug);
    return c != null && c.isReady ? c : null;
  }
}

/// `m:ss` — clips run from seconds to a few minutes.
String formatClock(Duration d) {
  final s = d.inSeconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}
