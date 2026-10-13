// Long Ký landing — static build. No bundler: Sass → CSS, one template →
// vi + en pages, QR as inline SVG, small JS copied as is.
//   node build.mjs            one build into dist/
//   node build.mjs --serve    build, watch src/, serve dist/ on :3030
import * as sass from 'sass';
import QRCode from 'qrcode';
import { createHash } from 'node:crypto';
import { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync, watch, writeFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { dirname, extname, join, normalize } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const repo = join(here, '..', '..');
const src = join(here, 'src');
const dist = join(here, 'dist');
const ORIGIN = process.env.SITE_ORIGIN || 'https://long-ky.com';
const GET_URL = `${ORIGIN}/get`;

const read = (p) => readFileSync(p, 'utf8');
const json = (p) => JSON.parse(read(p));
const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const hash = (s) => createHash('sha1').update(s).digest('hex').slice(0, 8);
const dig = (o, path) => path.split('.').reduce((a, k) => (a == null ? a : a[k]), o);

/** {{key.path}} is HTML-escaped; {{{key}}} is raw. */
function render(tpl, data) {
  return tpl
    .replace(/\{\{\{([\w.]+)\}\}\}/g, (_, k) => String(dig(data, k) ?? ''))
    .replace(/\{\{([\w.]+)\}\}/g, (_, k) => esc(dig(data, k) ?? ''));
}

function picture(name, widths, { sizes = '100vw', alt = '', lazy = true, width, height, cls = '' } = {}) {
  const set = (ext) => widths.map((w) => `/assets/img/${name}-${w}.${ext} ${w}w`).join(', ');
  return `<picture${cls ? ` class="${cls}"` : ''}><source type="image/avif" srcset="${set('avif')}" sizes="${sizes}"><img src="/assets/img/${name}-${widths[0]}.webp" srcset="${set('webp')}" sizes="${sizes}" alt="${esc(alt)}"${lazy ? ' loading="lazy" decoding="async"' : ''}${width ? ` width="${width}" height="${height}"` : ''}></picture>`;
}


/** The policy is edited as markdown in docs/play-store/privacy-policy.md. */
function inlineMd(t) {
  return esc(t)
    .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    .replace(/\[([^\]]+)\]\((https?:[^)]+)\)/g, '<a href="$2" rel="noopener">$1</a>')
    .replace(/(^|[\s>(])(help@long-ky\.com)/g, '$1<a href="mailto:$2">$2</a>');
}
function mdToHtml(md) {
  const out = [];
  for (const block of md.trim().split(/\n\s*\n/)) {
    const b = block.trim();
    if (!b || /^-{3,}$/.test(b)) continue;
    if (b.startsWith('### ')) out.push(`<h2>${inlineMd(b.slice(4))}</h2>`);
    else out.push(`<p>${inlineMd(b.replace(/\n/g, ' '))}</p>`);
  }
  return out.join('\n');
}
function policyFor(lang) {
  const md = read(join(repo, 'docs/play-store/privacy-policy.md'));
  const vi = md.indexOf('## Tiếng Việt'), en = md.indexOf('## English');
  if (vi < 0 || en < 0) throw new Error('privacy-policy.md: expected "## Tiếng Việt" and "## English" headings');
  let part = lang === 'vi' ? md.slice(vi + '## Tiếng Việt'.length, en) : md.slice(en + '## English'.length);
  // The "last updated" line is shown in the page header, not in the body.
  const m = part.match(/\*\*(?:Cập nhật lần cuối|Last updated):\s*([^*]+)\*\*/);
  if (!m) throw new Error('privacy-policy.md: missing the last-updated line');
  part = part.replace(m[0], '');
  if (/\[[^\]]*\](?!\()/.test(part.replace(/\[[^\]]+\]\([^)]+\)/g, ''))) throw new Error('privacy-policy.md still has a [placeholder]');
  return { html: mdToHtml(part), updated: m[1].trim() };
}

async function build() {
  rmSync(dist, { recursive: true, force: true });
  mkdirSync(join(dist, 'assets'), { recursive: true });

  // --- CSS / JS (content-hashed names so they can be cached forever) ---
  const css = sass.compile(join(src, 'styles/main.scss'), { style: 'compressed' }).css;
  const cssName = `assets/main.${hash(css)}.css`;
  writeFileSync(join(dist, cssName), css);
  const js = read(join(src, 'scripts/main.js'));
  const jsName = `assets/main.${hash(js)}.js`;
  writeFileSync(join(dist, jsName), js);

  // Static assets and public files.
  cpSync(join(src, 'assets'), join(dist, 'assets'), { recursive: true });
  if (existsSync(join(here, 'public'))) cpSync(join(here, 'public'), dist, { recursive: true });

  // --- Content-derived data ---
  const periods = json(join(repo, 'content/periods.json')).periods;
  const layers = json(join(src, 'layers.json'));
  const counts = {
    streets: json(join(repo, 'content/streets/hcm.json')).streets.length,
    people: json(join(repo, 'content/people.json')).people.length,
    events: json(join(repo, 'content/events.json')).events.length,
    eras: readdirSync(join(repo, 'content/eras')).filter((f) => f.endsWith('.json')).length,
  };
  const nf = (n, lang) => new Intl.NumberFormat(lang === 'vi' ? 'vi-VN' : 'en-US').format(n);

  // --- QR: dark lacquer modules on parchment, with a proper quiet zone ---
  const qr = await QRCode.toString(GET_URL, {
    type: 'svg', margin: 2, errorCorrectionLevel: 'M',
    color: { dark: '#07100f', light: '#f2ead9' },
  });
  writeFileSync(join(dist, 'assets/qr.svg'), qr);

  const usedVideos = existsSync(join(src, 'assets/video')) ? readdirSync(join(src, 'assets/video')) : [];

  for (const lang of ['vi', 'en']) {
    const t = json(join(src, `i18n/${lang}.json`));
    const other = lang === 'vi' ? 'en' : 'vi';

    // Depth rail: most recent on top, Hồng Bàng at the bottom.
    const layerByPeriod = new Map(layers.map((l) => [l.period, l]));
    const rail = [...periods].sort((a, b) => b.order - a.order).map((p) => {
      const layer = layerByPeriod.get(p.id);
      const title = p.title[lang] || p.title.vi;
      return `<li class="rail__tick${layer ? ' rail__tick--layer' : ''}" data-period="${p.id}" style="--c:${p.accent}"><span>${esc(title)}</span></li>`;
    }).join('');

    const layersHtml = layers.map((l, i) => {
      const c = l[lang];
      const year = lang === 'en' && l.yearEn ? l.yearEn : l.year;
      const hasVideo = l.video && usedVideos.includes(`${l.video}.mp4`);
      const art = l.art
        ? picture(l.art, l.art.startsWith('poster-') ? [900, 1440] : l.art === 'hcm-2026' ? [900, 1600, 2400] : [900, 1600], { sizes: '100vw', lazy: i > 1, cls: 'layer__img' })
        : '<div class="layer__img layer__img--plain"></div>';
      const [vFrom, vTo] = l.videoRange || [0, 5];
      const video = hasVideo ? `<video class="layer__video" muted playsinline preload="none" data-scrub data-src="/assets/video/${l.video}.mp4" data-from="${vFrom}" data-to="${vTo}" tabindex="-1" aria-hidden="true"></video>` : '';
      const shot = l.shot
        ? `<figure class="layer__shot">${picture(`shot-${lang}-${l.shot}`, [520], { sizes: '(min-width: 900px) 320px, 70vw', alt: `${t.alt.shot} — ${c.label}`, width: 520, height: l.shotH || 924 })}</figure>`
        : '';
      const stats = l.id === 'today'
        ? `<p class="layer__stats"><b>${nf(counts.streets, lang)}</b> ${t.stats.streets} · <b>${nf(counts.people, lang)}</b> ${t.stats.people}</p>`
        : '';
      return `
    <section class="layer${l.shot ? ' layer--shot' : ''}${i % 2 ? ' layer--flip' : ''}${l.bright ? ' layer--bright' : ''}" id="${l.id}" data-layer="${l.id}" data-scrub-host data-period="${l.period}" data-year="${esc(year)}" data-accent="${l.accent}" style="--accent:${l.accent}${l.focus ? `;--focus:${l.focus}` : ''}">
      <div class="layer__stage">
        <div class="layer__bg" aria-hidden="true">${art}${video}<span class="layer__veil"></span></div>
        <div class="layer__copy">
          <p class="kicker">${esc(c.kicker)}</p>
          <p class="layer__year" aria-hidden="true">${esc(year)}</p>
          <h2 class="layer__title">${esc(c.title)}</h2>
          <p class="layer__body">${esc(c.body)}</p>
          ${stats}
        </div>
        ${shot}
      </div>
    </section>`;
    }).join('\n');

    const heroStats = `<b>${nf(counts.eras, lang)}</b> ${t.stats.eras} · <b>${nf(counts.events, lang)}</b> ${t.stats.events} · <b>${nf(counts.people, lang)}</b> ${t.stats.people} · <b>${nf(counts.streets, lang)}</b> ${t.stats.streets}`;

    const jsonld = JSON.stringify({
      '@context': 'https://schema.org', '@type': 'MobileApplication',
      name: 'Long Ký', applicationCategory: 'EducationalApplication', operatingSystem: 'Android',
      description: t.meta.description, inLanguage: ['vi', 'en'], url: `${ORIGIN}${t.path}`,
      offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD' },
      author: { '@type': 'Organization', name: 'Long Ký', email: 'help@long-ky.com' },
    });

    const data = {
      ...t, origin: ORIGIN, altLang: other, css: `/${cssName}`, js: `/${jsName}`,
      layers: layersHtml, railHtml: rail, heroStats, jsonld,
      heroVideo: usedVideos.includes('dragon.mp4') ? '<video muted playsinline preload="none" data-scrub data-src="/assets/video/dragon.mp4" data-from="0" data-to="5" tabindex="-1" aria-hidden="true"></video>' : '',
      qr: qr.replace('<svg', '<svg aria-hidden="true" focusable="false"'),
      finalYear: lang === 'en' ? '2879 BCE' : '2879 TCN',
    };
    const outDir = lang === 'vi' ? dist : join(dist, 'en');
    mkdirSync(join(outDir, 'get'), { recursive: true });
    writeFileSync(join(outDir, 'index.html'), render(read(join(src, 'index.template.html')), data));
    writeFileSync(join(outDir, 'get/index.html'), render(read(join(src, 'get.template.html')), data));
    const pol = policyFor(lang);
    mkdirSync(join(outDir, 'privacy'), { recursive: true });
    writeFileSync(join(outDir, 'privacy/index.html'), render(read(join(src, 'privacy.template.html')), { ...data, privacyBody: pol.html, privacyUpdated: esc(pol.updated) }));
  }

  // --- Crawl files ---
  writeFileSync(join(dist, 'robots.txt'), `User-agent: *\nAllow: /\nDisallow: /get/\nSitemap: ${ORIGIN}/sitemap.xml\n`);
  writeFileSync(join(dist, 'sitemap.xml'),
    `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">\n` +
    ['/', '/en/', '/privacy/', '/en/privacy/'].map((p) => `  <url><loc>${ORIGIN}${p}</loc>${p.includes('privacy') ? `<xhtml:link rel="alternate" hreflang="vi" href="${ORIGIN}/privacy/"/><xhtml:link rel="alternate" hreflang="en" href="${ORIGIN}/en/privacy/"/>` : `<xhtml:link rel="alternate" hreflang="vi" href="${ORIGIN}/"/><xhtml:link rel="alternate" hreflang="en" href="${ORIGIN}/en/"/>`}</url>`).join('\n') +
    `\n</urlset>\n`);
  console.log(`built → ${dist}  (${cssName}, ${jsName})`);
}

await build();

if (process.argv.includes('--serve')) {
  let timer;
  watch(src, { recursive: true }, () => { clearTimeout(timer); timer = setTimeout(() => build().catch(console.error), 150); });
  const types = { '.html': 'text/html; charset=utf-8', '.css': 'text/css', '.js': 'text/javascript', '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg', '.webp': 'image/webp', '.avif': 'image/avif', '.woff2': 'font/woff2', '.mp4': 'video/mp4', '.xml': 'application/xml', '.txt': 'text/plain' };
  createServer((req, res) => {
    let p = normalize(decodeURIComponent(req.url.split('?')[0])).replace(/^(\.\.[/\\])+/, '');
    let f = join(dist, p);
    if (existsSync(f) && statSync(f).isDirectory()) f = join(f, 'index.html');
    if (!existsSync(f)) { res.writeHead(404); return res.end('not found'); }
    const body = readFileSync(f);
    const type = types[extname(f)] || 'application/octet-stream';
    // Range support: browsers need it to seek in <video>.
    const m = /^bytes=(\d*)-(\d*)$/.exec(req.headers.range || '');
    if (m && (m[1] || m[2])) {
      const start = m[1] ? Number(m[1]) : body.length - Number(m[2]);
      const end = m[1] && m[2] ? Math.min(Number(m[2]), body.length - 1) : body.length - 1;
      res.writeHead(206, { 'Content-Type': type, 'Accept-Ranges': 'bytes', 'Content-Range': `bytes ${start}-${end}/${body.length}`, 'Content-Length': end - start + 1 });
      return res.end(body.subarray(start, end + 1));
    }
    res.writeHead(200, { 'Content-Type': type, 'Accept-Ranges': 'bytes', 'Content-Length': body.length });
    res.end(body);
  }).listen(Number(process.env.PORT) || 3030, function () { console.log('http://localhost:' + this.address().port); });
}
