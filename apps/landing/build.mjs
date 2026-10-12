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
        ? picture(l.art, [900, 1600], { sizes: '100vw', lazy: i > 1, cls: 'layer__img' })
        : '<div class="layer__img layer__img--plain"></div>';
      const video = hasVideo ? `<video class="layer__video" muted loop playsinline preload="none" data-src="/assets/video/${l.video}.mp4" tabindex="-1" aria-hidden="true"></video>` : '';
      const shot = l.shot
        ? `<figure class="layer__shot">${picture(`shot-${lang}-${l.shot}`, [520], { sizes: '(min-width: 900px) 320px, 70vw', alt: `${t.alt.shot} — ${c.label}`, width: 520, height: l.shotH || 924 })}</figure>`
        : '';
      const stats = l.id === 'today'
        ? `<p class="layer__stats"><b>${nf(counts.streets, lang)}</b> ${t.stats.streets} · <b>${nf(counts.people, lang)}</b> ${t.stats.people}</p>`
        : '';
      return `
    <section class="layer${l.shot ? ' layer--shot' : ''}${i % 2 ? ' layer--flip' : ''}" id="${l.id}" data-layer="${l.id}" data-period="${l.period}" data-year="${esc(year)}" data-accent="${l.accent}" style="--accent:${l.accent}">
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
      heroVideo: usedVideos.includes('dragon.mp4') ? '<video muted loop playsinline preload="none" data-src="/assets/video/dragon.mp4" tabindex="-1"></video>' : '',
      qr: qr.replace('<svg', '<svg aria-hidden="true" focusable="false"'),
      finalYear: lang === 'en' ? '2879 BCE' : '2879 TCN',
    };
    const outDir = lang === 'vi' ? dist : join(dist, 'en');
    mkdirSync(join(outDir, 'get'), { recursive: true });
    writeFileSync(join(outDir, 'index.html'), render(read(join(src, 'index.template.html')), data));
    writeFileSync(join(outDir, 'get/index.html'), render(read(join(src, 'get.template.html')), data));
  }

  // --- Crawl files ---
  writeFileSync(join(dist, 'robots.txt'), `User-agent: *\nAllow: /\nDisallow: /get/\nSitemap: ${ORIGIN}/sitemap.xml\n`);
  writeFileSync(join(dist, 'sitemap.xml'),
    `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">\n` +
    ['/', '/en/'].map((p) => `  <url><loc>${ORIGIN}${p}</loc><xhtml:link rel="alternate" hreflang="vi" href="${ORIGIN}/"/><xhtml:link rel="alternate" hreflang="en" href="${ORIGIN}/en/"/></url>`).join('\n') +
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
    res.writeHead(200, { 'Content-Type': types[extname(f)] || 'application/octet-stream' });
    res.end(readFileSync(f));
  }).listen(3030, () => console.log('http://localhost:3030'));
}
