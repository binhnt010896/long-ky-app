import 'dart:math';

import '../quiz/quiz_generator.dart' show dailySeed;

/// Today's gift: one of the still-hidden [remaining] keys, at random.
///
/// Stable for the whole day (the same inputs give the same pick), different
/// from day to day, and different between installs through [installSeed].
/// Null when nothing is left to unlock.
String? dailyGiftPick(
  Iterable<String> remaining,
  DateTime date,
  int installSeed,
) {
  final sorted = remaining.toList()..sort();
  if (sorted.isEmpty) return null;
  final rng = Random(dailySeed(date) * 31 + installSeed);
  return sorted[rng.nextInt(sorted.length)];
}
