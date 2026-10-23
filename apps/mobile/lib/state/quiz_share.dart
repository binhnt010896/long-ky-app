/// Where a shared result points. The Play listing is not public yet, so this
/// is the landing page's /get redirect, which already serves the right page
/// either way (see apps/landing/public/_redirects).
const String kShareLink = 'long-ky.com/get';

/// The spoiler-free text shared after a "Câu đố hôm nay": the date, one square
/// per question in order (🟨 right, ⬛ wrong) and the score — never a question
/// or an answer. Wordle's trick: a result can be compared without spoiling
/// the quiz, so it can be posted anywhere.
String dailyShareText({
  required DateTime day,
  required List<bool> marks,
  required bool en,
}) {
  String two(int n) => n.toString().padLeft(2, '0');
  final date = '${two(day.day)}/${two(day.month)}/${day.year}';
  final grid = marks.map((m) => m ? '🟨' : '⬛').join();
  final score = marks.where((m) => m).length;
  final title = en ? 'Long Ký · Today\'s quiz' : 'Long Ký · Câu đố hôm nay';
  return '$title $date\n$grid  $score/${marks.length}\n$kShareLink';
}
