/// The conventional path for a newly added avatar/full-body image — used
/// by "Add avatar"/"Add full body" on the People page (Cycle I's I-3).
/// Files under the era folder of the first era that already references
/// this person, matching every existing image's layout
/// (`eras/<slug>/characters/<id>-<suffix>.png`); a person nobody
/// references yet has no natural era folder, so it goes under a new
/// top-level `people/` folder instead.
String personAssetPath({required String id, required List<String> usedIn, required String suffix}) {
  final folder = usedIn.isNotEmpty ? 'eras/${usedIn.first}/characters' : 'people';
  return '$folder/$id-$suffix.png';
}
