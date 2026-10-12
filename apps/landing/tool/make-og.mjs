// 1200×630 share image: the splash dragon, cropped, with the seal.
import sharp from 'sharp';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..');
const bg = await sharp(join(root, 'brand/splash/splash-dragon.png')).resize({ width: 1200 }).extract({ left: 0, top: 90, width: 1200, height: 630 }).toBuffer();
const seal = await sharp(join(root, 'brand/logo/longky-01-circle-oxblood.png')).resize(230, 230).toBuffer();
await sharp(bg).composite([{ input: seal, left: 90, top: 200 }]).jpeg({ quality: 82 }).toFile(join(root, 'apps/landing/public/og.jpg'));
