// Builds the narration job list: one speakable Vietnamese text per era,
// person and event, plus a hash so a later text edit regenerates only that
// item's audio. Writes content/audio/narration-jobs.json, preserving the
// `status` of any job whose hash did not change.
//
// Usage: node tool/narration_jobs.mjs [--lint]   (--lint prints leftover digit patterns)
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';

const LANG = 'vi';
const OUT = 'content/audio/narration-jobs.json';
const read = (p) => JSON.parse(readFileSync(p, 'utf8'));
const vi = (lt) => (lt && typeof lt === 'object' ? lt[LANG] ?? '' : '').trim();

const ROMAN = { I: 1, V: 5, X: 10, L: 50 };
const romanToInt = (r) => [...r].reduce((n, c, i, a) => n + (ROMAN[c] < (ROMAN[a[i + 1]] ?? 0) ? -ROMAN[c] : ROMAN[c]), 0);
const ONES = ['không', 'một', 'hai', 'ba', 'bốn', 'năm', 'sáu', 'bảy', 'tám', 'chín'];
const viNum = (n) => {
  if (n < 10) return ONES[n];
  if (n === 10) return 'mười';
  if (n < 20) return `mười ${n % 10 === 5 ? 'lăm' : ONES[n % 10]}`;
  const t = Math.floor(n / 10), o = n % 10;
  return `${ONES[t]} mươi${o ? ` ${o === 1 ? 'mốt' : o === 5 ? 'lăm' : ONES[o]}` : ''}`;
};

/// Rewrites what a TTS voice would misread: BCE/CE markers, date and year
/// ranges, roman numerals, a few abbreviations.
export function speakable(raw) {
  let s = raw
    .replace(/≈\s*/g, 'khoảng ')
    .replace(/\bkhoảng\s+(\d{1,4})\s*TCN/g, 'khoảng năm $1 trước Công nguyên')
    .replace(/\b(\d{1,4})\s*[–-]\s*(\d{1,4})\s*TCN/g, 'từ năm $1 đến năm $2 trước Công nguyên')
    .replace(/(?<![Nn]ăm )\b(\d{1,4})\s*TCN/g, 'năm $1 trước Công nguyên')
    .replace(/\b(\d{1,4})\s*TCN/g, '$1 trước Công nguyên')
    .replace(/\bTCN\b/g, 'trước Công nguyên')
    // dates that already carry the year ("7/5/1954 SCN", "tháng 12, 1972 SCN"): drop the era marker
    .replace(/(\/\d{4})\s*SCN\b/g, '$1')
    .replace(/(\b\d{1,2}\s*[–-]\s*\d{1,2},\s*\d{4})\s*SCN\b/g, '$1')
    // thousands separators (1.200 → 1200) so the voice does not read a decimal point
    .replace(/\b(\d{1,3})\.(\d{3})\b/g, '$1$2')
    // "27 tháng 1, 1973 SCN" / "1945 SCN": CE years are read plain, no era suffix
    .replace(/\b(\d{1,4})\s*[–-]\s*(\d{1,4})\s*SCN\b/g, 'từ năm $1 đến năm $2')
    .replace(/\b(\d{1,2})\s*[–-]\s*(\d{1,2}) tháng (\d{1,2}),? (\d{4})\s*SCN\b/g, 'từ ngày $1 đến ngày $2 tháng $3 năm $4')
    .replace(/\b(\d{1,2}) tháng (\d{1,2}),? (\d{4})\s*SCN\b/g, 'ngày $1 tháng $2 năm $3')
    // "3, 1975 SCN": a bare month and year
    .replace(/(?<![\d–-]\s*)(?<![Tt]háng\s)\b(\d{1,2}),\s*(\d{4})\s*SCN\b/g, 'tháng $1 năm $2')
    .replace(/(?<![Nn]ăm )\b(\d{3,4})\s*SCN\b/g, 'năm $1')
    .replace(/\b(\d{3,4})\s*SCN\b/g, '$1')
    .replace(/\bSCN\b/g, 'sau Công nguyên')
    .replace(/\((\d{4})\s*[–-]\s*\)/g, '(sinh năm $1)')
    // 30/12/1999 – 25/12/2000 → two full dates
    .replace(/\b(\d{1,2})\/(\d{1,2})\/(\d{4})\s*[–-]\s*(\d{1,2})\/(\d{1,2})\/(\d{4})\b/g, 'từ ngày $1 tháng $2 năm $3 đến ngày $4 tháng $5 năm $6')
    // 17/2 – 18/3/1979 → two full dates
    .replace(/\b(\d{1,2})\/(\d{1,2})\s*[–-]\s*(\d{1,2})\/(\d{1,2})\/(\d{4})\b/g, 'từ ngày $1 tháng $2 đến ngày $3 tháng $4 năm $5')
    // "tháng 12, 1972" → "tháng 12 năm 1972"
    .replace(/(tháng \d{1,2}),\s*(\d{4})\b/g, '$1 năm $2')
    // 13-3 – 7/5/1954 → two full dates
    .replace(/\b(\d{1,2})-(\d{1,2})\s*[–-]\s*(\d{1,2})\/(\d{1,2})\/(\d{4})\b/g, 'từ ngày $1 tháng $2 đến ngày $3 tháng $4 năm $5')
    // "8 – 9, 1945": a month range, not days
    .replace(/(?<![\d\/])\b(\d{1,2})\s*[–-]\s*(\d{1,2}),\s*(\d{4})\b/g, 'tháng $1 đến tháng $2 năm $3')
    // d-m-yyyy / d/m/yyyy
    .replace(/\b(\d{1,2})\s*[-\/]\s*(\d{1,2})\s*[-\/]\s*(\d{4})\b/g, '$1 tháng $2 năm $3')
    // "Tháng 6/1991": keep the existing word, no doubled "tháng"
    .replace(/\b([Tt]háng)\s+(\d{1,2})\s*[\/-]\s*(\d{4})\b/g, '$1 $2 năm $3')
    // 2–3/1979 (month range) and 1965–66 (short year range)
    .replace(/\b(?:tháng\s+)?(\d{1,2})\s*[–-]\s*(\d{1,2})\/(\d{4})\b/g, 'tháng $1 đến tháng $2 năm $3')
    .replace(/\b(\d{2})(\d{2})\s*[–-]\s*(\d{2})\b(?!\d)/g, 'từ năm $1$2 đến năm $1$3')
    // m/yyyy, m-yyyy
    .replace(/\b(\d{1,2})\s*[\/-]\s*(\d{4})\b/g, 'tháng $1 năm $2')
    .replace(/\((\d{4})\s*[–-]\s*nay\)/g, '(từ năm $1 đến nay)')
    // "những năm 1981–1983" → "những năm từ 1981 đến 1983", not "những từ năm …"
    .replace(/\b(những|các|suốt|qua)\s+năm\s+(\d{4})\s*[–-]\s*(\d{4})\b/g, '$1 năm từ $2 đến $3')
    // "năm 1075–1076" → no doubled "năm"
    .replace(/\bnăm\s+(\d{4})\s*[–-]\s*(\d{4})\b/g, 'từ năm $1 đến năm $2')
    .replace(/\bNăm\s+(\d{4})\s*[–-]\s*(\d{4})\b/g, 'Từ năm $1 đến năm $2')
    // yyyy–yyyy
    .replace(/\b(\d{4})\s*[–-]\s*(\d{4})\b/g, 'từ năm $1 đến năm $2')
    // "trong hai năm 1975–1976" → "trong hai năm, từ năm 1975 đến năm 1976"
    .replace(/\b(\d{1,2}|hai|ba|bốn|sáu|bảy|tám|chín|mười)\s+từ năm (\d{4}) đến năm (\d{4})/g, '$1 năm, từ năm $2 đến năm $3')
    // "Sắc lệnh số 29-LCT": say who issued it instead of the code
    .replace(/\b(\d{1,3})-LCT\b/g, '$1 của Chủ tịch nước')
    // clock times: 9h47 → 9 giờ 47 phút, 17h → 17 giờ
    .replace(/\b(\d{1,2})h(\d{2})\b/g, '$1 giờ $2 phút')
    .replace(/\b(\d{1,2})h\b/g, '$1 giờ')
    .replace(/\b(\d{1,3})\/(\d{1,3})\s+phiếu\b/g, '$1 trên $2 phiếu')
    // statute numbers like "Luật 10/59" are not dates
    .replace(/\bLuật 10\/59\b/g, 'Luật 10 năm 1959')
    // d/m (28/7) and "ngày d-m"
    .replace(/\b(\d{1,2})\s*\/\s*(\d{1,2})\b/g, '$1 tháng $2')
    .replace(/\b([Nn]gày)\s+(\d{1,2})\s*[–-]\s*(\d{1,2})\b(?!\d)(?!\s*(tháng|\/))/g, (m, w, a, b) => (+a > +b && +b <= 12 ? `${w} ${a} tháng ${b}` : m))
    // "ngày 25-26" / "tháng 8-9"
    .replace(/\b(ngày|tháng)\s+(\d{1,2})\s*[–-]\s*(\d{1,2})\b/g, 'từ $1 $2 đến $1 $3')
    // 18–30
    // 19–8 (descending, month ≤ 12) is a date; 7–10 is a range
    .replace(/\b(\d{1,3})\s*[–-]\s*(\d{1,3})\b/g, (m, a, b) => (+a > +b && +a <= 31 && +b <= 12 ? `${a} tháng ${b}` : `từ ${a} đến ${b}`))
    // "trong hai ngày 3–4 tháng 9" → "trong hai ngày, từ ngày 3 đến ngày 4 tháng 9"
    .replace(/\b(hai|ba|bốn|\d{1,2})\s+từ ngày (\d{1,2}) đến ngày (\d{1,2})/g, '$1 ngày, từ ngày $2 đến ngày $3')
    // "Ngày từ 10 đến 11 tháng 11" → "Từ ngày 10 đến 11 tháng 11"
    .replace(/\bNgày từ (?=\d)/g, 'Từ ngày ')
    .replace(/\bthứ\s+IV\b/g, 'thứ tư')
    // roman numerals (Đại hội VI, thế kỷ XX, khoá IX, X)
    .replace(/(?<![\p{L}\d])(?=[IVXL]+(?![\p{L}\d]))((?:X{0,3})(?:IX|IV|V?I{0,3}))(?![\p{L}\d])/gu, (m) => (m ? viNum(romanToInt(m)) : m))
    // Abbreviations a voice would spell out letter by letter: say the full name.
    .replace(/\bVNDCCH\b/g, 'Việt Nam Dân chủ Cộng hòa')
    .replace(/\bCHXHCN\b/g, 'Cộng hòa Xã hội Chủ nghĩa')
    .replace(/\bLHQ\b/g, 'Liên Hợp Quốc')
    .replace(/\bWTO\b/g, 'Tổ chức Thương mại Thế giới')
    .replace(/\bGDP\b/g, 'tổng sản phẩm trong nước')
    .replace(/(tổng sản phẩm trong nước) \(\1\)/g, '$1')
    .replace(/\bGNI\b/g, 'tổng thu nhập quốc dân')
    .replace(/\bSEV\b/g, 'Hội đồng Tương trợ Kinh tế')
    .replace(/(Hội đồng Tương trợ Kinh tế) \(\1(, hay Comecon)?\)/g, (m, a, b) => (b ? `${a}${b}` : a))
    .replace(/((?:\d{1,2} )?tháng \d{1,2}(?: năm \d{4})?)\s+·\s+((?:\d{1,2} )?tháng \d{1,2})/g, '$1 và $2')
    .replace(/\bTP\.\s*/g, 'Thành phố ')
    .replace(/\bTP\b\s*/g, 'Thành phố ')
    // "số 10-NQ/TW", "100-CT/TW": the code is not read out
    .replace(/\b(\d{1,3})-(?:CT|NQ)\/TW\b/g, '$1 của Trung ương')
    .replace(/(\d)\s*%/g, '$1 phần trăm')
    .replace(/\bUSD\b/g, 'đô la Mỹ')
    // "Từ 11–19 tháng 2" already starts with Từ: no doubled "từ từ"
    .replace(/\b([Tt])ừ từ (?=\d)/g, '$1ừ ')
    .replace(/\s*—\s*/g, ', ')
    .replace(/[“”"]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
  if (s && !/[.!?…]$/.test(s)) s += '.';
  return s;
}

const sentence = (t) => (t ? (/[.!?…]$/.test(t) ? t : `${t}.`) : '');
const hash = (t) => createHash('sha256').update(t).digest('hex').slice(0, 12);

const jobs = [];
const add = (type, id, parts) => {
  const text = parts.map(speakable).filter(Boolean).join('\n\n');
  if (text) jobs.push({ id: `${type}/${id}`, type, slug: id, chars: text.length, hash: hash(text), text });
};

for (const f of readdirSync('content/eras').filter((n) => n.endsWith('.json')).sort()) {
  const e = read(`content/eras/${f}`);
  add('eras', e.slug, [
    sentence(vi(e.title)),
    sentence([vi(e.yearRange?.display), vi(e.kicker)].filter(Boolean).join(', ')),
    sentence(vi(e.subtitle)),
    vi(e.overview),
  ]);
}
for (const p of read('content/people.json').people) {
  add('people', p.id, [sentence(vi(p.name)), sentence(vi(p.epithet)), vi(p.bio)]);
}
for (const ev of read('content/events.json').events) {
  add('events', ev.id, [
    sentence(vi(ev.title)),
    sentence(vi(ev.year?.display)),
    vi(ev.body),
    vi(ev.details),
  ]);
}

const prev = existsSync(OUT) ? new Map(read(OUT).jobs.map((j) => [j.id, j])) : new Map();
for (const j of jobs) {
  const old = prev.get(j.id);
  j.status = old && old.hash === j.hash ? old.status ?? 'pending' : 'pending';
  if (old && old.hash === j.hash && old.durationSecs) j.durationSecs = old.durationSecs;
}
mkdirSync('content/audio', { recursive: true });
writeFileSync(OUT, JSON.stringify({ lang: LANG, jobs }, null, 2) + '\n');
const total = jobs.reduce((n, j) => n + j.chars, 0);
console.log(`${jobs.length} jobs, ${total} chars (${jobs.filter((j) => j.status === 'pending').length} pending)`);

if (process.argv.includes('--lint')) {
  for (const j of jobs) for (const m of j.text.matchAll(/.{0,25}(\d+[–-]\d+|[–-]\d|\d[–-]|[A-Z]{2,}\b).{0,25}/g)) console.log(`${j.id}: ${m[0]}`);
}
