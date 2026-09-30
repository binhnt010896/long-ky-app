import 'street_map.dart';
import 'street_name.dart';

/// Turns a street name into its slug id (`Lê Lợi` → `le-loi`). ASCII-folds
/// Vietnamese so ids are URL/analytics friendly.
String streetSlug(String name) {
  const from = 'àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ';
  const to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
  final n = normalizeName(name, stripStreetPrefix: true);
  final b = StringBuffer();
  for (final r in n.runes) {
    final c = String.fromCharCode(r);
    final i = from.indexOf(c);
    b.write(i >= 0 ? to[i] : c);
  }
  return b
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

/// A candidate name → targets index built from the content, plus the curated
/// alias list. Pure: takes decoded JSON, never touches the filesystem.
class StreetMatcher {
  StreetMatcher._(this._exact, this._alias);

  final Map<String, List<StreetTarget>> _exact;
  final Map<String, List<StreetTarget>> _alias;

  /// [people] is `people.json`'s `people` list; [eras] the decoded era maps;
  /// [aliases] is `content/streets/aliases.json`'s `aliases` list
  /// (`{street, targets:[{type,id,era?}]}`).
  factory StreetMatcher.fromContent({
    required List<Map<String, dynamic>> people,
    required List<Map<String, dynamic>> eras,
    List<Map<String, dynamic>> aliases = const [],
  }) {
    final sorted = [...eras]
      ..sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));
    // A person's home era is the earliest era (by order) whose roster lists
    // them — people.json carries none, but the figure route needs one.
    final home = <String, String>{};
    for (final e in sorted) {
      for (final c in (e['characters'] as List? ?? const [])) {
        home.putIfAbsent(
            (c as Map<String, dynamic>)['ref'] as String, () => e['slug'] as String);
      }
    }

    final exact = <String, List<StreetTarget>>{};
    void add(Map<String, List<StreetTarget>> into, String name, StreetTarget t) {
      final key = normalizeName(name, stripStreetPrefix: true);
      if (key.isEmpty) return;
      final list = into.putIfAbsent(key, () => []);
      if (!list.contains(t)) list.add(t);
    }

    for (final p in people) {
      final id = p['id'] as String;
      final era = home[id];
      if (era == null) continue; // on no roster → no route to open
      final vi = (p['name'] as Map<String, dynamic>)['vi'] as String;
      for (final v in personNameVariants(vi)) {
        add(exact, v,
            StreetTarget(type: StreetTargetType.person, id: id, era: era));
      }
    }
    for (final e in sorted) {
      final slug = e['slug'] as String;
      final title = (e['title'] as Map<String, dynamic>)['vi'] as String;
      add(exact, title,
          StreetTarget(type: StreetTargetType.era, id: slug, era: slug));
      for (final ev in (e['events'] as List? ?? const [])) {
        final m = ev as Map<String, dynamic>;
        final t = (m['title'] as Map<String, dynamic>)['vi'] as String;
        add(exact, t,
            StreetTarget(type: StreetTargetType.event, id: m['id'] as String, era: slug));
      }
    }

    final alias = <String, List<StreetTarget>>{};
    for (final a in aliases) {
      for (final t in (a['targets'] as List)) {
        final tj = t as Map<String, dynamic>;
        var target = StreetTarget.fromJson(tj);
        if (target.type == StreetTargetType.person && target.era.isEmpty) {
          target = StreetTarget(
              type: target.type, id: target.id, era: home[target.id] ?? '');
        }
        add(alias, a['street'] as String, target);
      }
    }
    return StreetMatcher._(exact, alias);
  }

  /// Proposes streets for [osmNames] (raw OSM `name` values, duplicates fine).
  ///
  /// Reasons: `exact` — exactly one target by name; `alias` — matched via the
  /// curated list; `multi` — more than one target. Only `exact` is auto
  /// approved (decision M3); the rest wait for the review table.
  List<MappedStreet> suggest(Iterable<String> osmNames) {
    final seen = <String>{};
    final out = <MappedStreet>[];
    for (final raw in osmNames) {
      final key = normalizeName(raw, stripStreetPrefix: true);
      if (key.isEmpty || !seen.add(key)) continue;
      final aliasHit = _alias[key];
      final exactHit = _exact[key];
      final targets = <StreetTarget>[
        ...?aliasHit,
        for (final t in exactHit ?? const <StreetTarget>[])
          if (!(aliasHit?.contains(t) ?? false)) t,
      ];
      if (targets.isEmpty) continue;
      final reason = targets.length > 1
          ? 'multi'
          : (aliasHit != null ? 'alias' : 'exact');
      out.add(MappedStreet(
        id: streetSlug(raw),
        name: canonicalSpelling(raw).replaceFirst(
            RegExp(r'^(Đại lộ|Đường|Phố)\s+', caseSensitive: false), ''),
        targets: targets,
        status:
            reason == 'exact' ? StreetStatus.approved : StreetStatus.suggested,
        reason: reason,
      ));
    }
    out.sort((a, b) => a.id.compareTo(b.id));
    return out;
  }

  /// Merges a fresh [suggested] run into the [existing] file. A re-run never
  /// un-approves, never edits an existing entry (hand edits win), and only
  /// appends streets that are new. Existing streets missing from the new run
  /// are kept as-is.
  static List<MappedStreet> merge(
      List<MappedStreet> existing, List<MappedStreet> suggested) {
    final byId = {for (final s in existing) s.id: s};
    final out = [...existing];
    for (final s in suggested) {
      if (!byId.containsKey(s.id)) {
        out.add(s);
        byId[s.id] = s;
      }
    }
    out.sort((a, b) => a.id.compareTo(b.id));
    return out;
  }
}
