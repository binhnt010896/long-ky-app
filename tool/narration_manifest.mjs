// Writes build/audio/manifest.json: the narration clips that exist and are
// current. The app fetches it and only requests clips listed here, so a page
// without a clip (events not generated yet, text edited since) never hits a
// 404. `v` is the text hash from narration-jobs.json — it busts the CDN cache
// when a clip is regenerated under the same file name.
//
// Run `node tool/narration_jobs.mjs` first so statuses and hashes are fresh.
import { existsSync, mkdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';

const jobs = JSON.parse(readFileSync('content/audio/narration-jobs.json', 'utf8')).jobs;
const clips = {};
const skipped = [];
for (const j of jobs) {
  if (j.status !== 'done') continue;
  const file = `content/audio/vi/${j.id}.mp3`;
  if (!existsSync(file) || statSync(file).size < 1000) { skipped.push(j.id); continue; }
  clips[j.id] = { v: j.hash, secs: j.durationSecs ?? null };
}
mkdirSync('build/audio', { recursive: true });
writeFileSync('build/audio/manifest.json', JSON.stringify({ version: 1, lang: 'vi', clips }, null, 1) + '\n');
console.log(`${Object.keys(clips).length} clips in manifest` + (skipped.length ? `; skipped (missing file): ${skipped.join(', ')}` : ''));
