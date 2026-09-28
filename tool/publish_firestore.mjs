#!/usr/bin/env node
// Writes content/eras/*.json, content/people.json and content/periods.json
// into Firestore, live-readable by the app (Cycle K5 —
// apps/mobile/lib/state/firestore_content_source.dart). Each document holds
// the exact canonical JSON text as a single `json` string field — no
// decomposition into native Firestore fields — so this script and the app
// stay exactly in sync with whatever core_domain's models expect, with zero
// duplicated shape logic.
//
// Collections:
//   eras/<slug>            { json, updatedAt }
//   singletons/people      { json, updatedAt }
//   singletons/periods     { json, updatedAt }
//
// Deletes any `eras` doc whose slug is no longer in content/index.json, so a
// removed era doesn't linger live in Firestore after it's gone from Git.
//
// Skips entirely (exit 0) if FIREBASE_SERVICE_ACCOUNT_KEY isn't set — so a
// repo that hasn't set up Firestore yet can still publish normally; the app
// simply keeps using the R2-pack path for everyone until this is configured.
// Never logs the key's contents.
//
// Usage: node tool/publish_firestore.mjs [--dry-run]
//   FIREBASE_SERVICE_ACCOUNT_KEY: the full JSON of a service-account key
//   with Cloud Firestore write access, as a GitHub Actions secret.

import { readFileSync } from 'node:fs';

const dryRun = process.argv.includes('--dry-run');

const keyJson = process.env.FIREBASE_SERVICE_ACCOUNT_KEY;
if (!keyJson) {
  console.log(
    '→ FIREBASE_SERVICE_ACCOUNT_KEY not set — skipping the Firestore write. ' +
      'The app still gets this content via the R2 pack.',
  );
  process.exit(0);
}

const { initializeApp, cert } = await import('firebase-admin/app');
const { getFirestore, FieldValue } = await import('firebase-admin/firestore');

let serviceAccount;
try {
  serviceAccount = JSON.parse(keyJson);
} catch (e) {
  console.error('✗ FIREBASE_SERVICE_ACCOUNT_KEY is not valid JSON.');
  process.exit(1);
}

let db;
try {
  initializeApp({ credential: cert(serviceAccount) });
  db = getFirestore();
} catch (e) {
  console.error(`✗ Firestore credential rejected: ${e.message ?? e}`);
  process.exit(1);
}

const readJson = (rel) => JSON.parse(readFileSync(`content/${rel}`, 'utf8'));
const readText = (rel) => readFileSync(`content/${rel}`, 'utf8');

const index = readJson('index.json');
const slugs = index.eras;

console.log(`→ ${dryRun ? '[dry run] would write' : 'writing'} ${slugs.length} era(s), people.json, periods.json…`);

if (dryRun) {
  process.exit(0);
}

let batch = db.batch();
let writes = 0;

function set(ref, json) {
  batch.set(ref, { json, updatedAt: FieldValue.serverTimestamp() });
  writes++;
}

for (const slug of slugs) {
  set(db.collection('eras').doc(slug), readText(`eras/${slug}.json`));
}
set(db.collection('singletons').doc('people'), readText('people.json'));
set(db.collection('singletons').doc('periods'), readText('periods.json'));

// Remove any era doc that's no longer referenced (a deleted or renamed era).
const existing = await db.collection('eras').listDocuments();
const liveSlugs = new Set(slugs);
let removed = 0;
for (const doc of existing) {
  if (!liveSlugs.has(doc.id)) {
    batch.delete(doc.ref);
    removed++;
  }
}

try {
  await batch.commit();
} catch (e) {
  console.error(`✗ Firestore write failed: ${e.message ?? e}`);
  process.exit(1);
}
console.log(`✓ wrote ${writes} document(s), removed ${removed} stale era doc(s).`);
