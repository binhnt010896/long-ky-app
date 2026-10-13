// Builds the optimised images and fonts the page uses from the repo's
// brand/ and content/ art. Run once with `npm run assets`; the outputs in
// src/assets are committed, because content/**/*.png is git-ignored.
import sharp from 'sharp';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import ttf2woff2 from 'ttf2woff2';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..');
const out = join(root, 'apps/landing/src/assets');
mkdirSync(join(out, 'img'), { recursive: true });
mkdirSync(join(out, 'fonts'), { recursive: true });

const jobs = [
  // [source, name, widths, quality]
  ['brand/splash/splash-dragon.png', 'dragon', [720, 1080], 62],
  ['content/periods/khang-chien-chong-phap.png', 'khang-chien', [900, 1600], 60],
  ['content/periods/tay-son.png', 'tay-son', [900, 1600], 60],
  ['content/periods/nha-tran.png', 'nha-tran', [900, 1600], 60],
  ['content/periods/nha-ly.png', 'nha-ly', [900, 1600], 60],
  ['content/periods/bac-thuoc.png', 'bac-thuoc', [900, 1600], 60],
  ['content/periods/hong-bang.png', 'hong-bang', [900, 1600], 60],
  ['content/periods/doi-moi.png', 'doi-moi', [900, 1600], 60],
  ['content/eras/hong-bang/scene/sky.png', 'hb-sky', [720], 55],
  // Landscape cut of the same sky (brand/landing), for wide screens.
  ['brand/landing/hong-bang-sky-landscape.png', 'hb-sky-wide', [1600, 2400], 58],
  ['content/eras/hong-bang/scene/ridge-far.png', 'hb-ridge-far', [1600], 60],
  ['content/eras/hong-bang/scene/ridge-near.png', 'hb-ridge-near', [1600], 60],
  ['content/eras/hong-bang/scene/glow.png', 'hb-glow', [1000], 55],
  ['brand/play-store/screenshots-vi/01-hong-bang.png', 'shot-vi-hong-bang', [520], 70],
  ['brand/play-store/screenshots-vi/02-map.png', 'shot-vi-map', [520], 70],
  ['brand/play-store/screenshots-vi/03-quang-trung.png', 'shot-vi-quang-trung', [520], 70],
  ['brand/play-store/screenshots-vi/04-son-tinh.png', 'shot-vi-son-tinh', [520], 70],
  ['brand/play-store/screenshots-vi/05-khang-chien.png', 'shot-vi-khang-chien', [520], 70],
  ['brand/play-store/screenshots-en/01-hong-bang.png', 'shot-en-hong-bang', [520], 70],
  ['brand/play-store/screenshots-en/02-map.png', 'shot-en-map', [520], 70],
  ['brand/play-store/screenshots-en/03-quang-trung.png', 'shot-en-quang-trung', [520], 70],
  ['brand/play-store/screenshots-en/04-son-tinh.png', 'shot-en-son-tinh', [520], 70],
  ['brand/play-store/screenshots-en/05-khang-chien.png', 'shot-en-khang-chien', [520], 70],
  ['brand/logo/longky-01-circle-oxblood.png', 'seal', [256, 512], 80],
  ['brand/landing/ho-chi-minh-2026-upscaled.png', 'hcm-2026', [900, 1600, 2400], 62],
  // Real phone screenshot of the street map; the Android status and
  // navigation bars are cropped off (900×2000 source → 900×1800).
  ['brand/landing/street-map-screenshot.jpg', 'shot-vi-street', [520], 72, { left: 0, top: 85, width: 900, height: 1800 }],
  ['brand/landing/street-map-screenshot.jpg', 'shot-en-street', [520], 72, { left: 0, top: 85, width: 900, height: 1800 }],
];

// `node tool/make-images.mjs hb-sky` rebuilds just that image.
const only = process.argv[2];
for (const [src, name, widths, q, crop] of jobs) {
  if (only && name !== only) continue;
  for (const w of widths) {
    let base = sharp(join(root, src));
    if (crop) base = sharp(await base.extract(crop).toBuffer());
    const img = base.resize({ width: w, withoutEnlargement: true });
    await img.clone().avif({ quality: q - 18, effort: 6 }).toFile(join(out, 'img', `${name}-${w}.avif`));
    await img.clone().webp({ quality: q + 8, effort: 6 }).toFile(join(out, 'img', `${name}-${w}.webp`));
  }
  console.log('ok', name);
}

if (only) process.exit(0);

// Fonts: TTF → WOFF2 (the app's own files, same family and weights).
const fonts = {
  'PlayfairDisplay-Variable': 'packages/ui_kit/fonts/PlayfairDisplay-Variable.ttf',
  'PlayfairDisplay-Italic-Variable': 'packages/ui_kit/fonts/PlayfairDisplay-Italic-Variable.ttf',
  'BeVietnamPro-Light': 'packages/ui_kit/fonts/BeVietnamPro-Light.ttf',
  'BeVietnamPro-Regular': 'packages/ui_kit/fonts/BeVietnamPro-Regular.ttf',
  'BeVietnamPro-Medium': 'packages/ui_kit/fonts/BeVietnamPro-Medium.ttf',
  'BeVietnamPro-SemiBold': 'packages/ui_kit/fonts/BeVietnamPro-SemiBold.ttf',
};
for (const [name, p] of Object.entries(fonts)) {
  writeFileSync(join(out, 'fonts', `${name}.woff2`), ttf2woff2(readFileSync(join(root, p))));
  console.log('font', name);
}

// Favicon + share image.
await sharp(join(root, 'brand/logo/longky-01-circle-oxblood.png')).resize(180, 180).png().toFile(join(root, 'apps/landing/public/apple-touch-icon.png'));
await sharp(join(root, 'brand/logo/longky-01-circle-oxblood.png')).resize(64, 64).png().toFile(join(root, 'apps/landing/public/favicon.png'));
