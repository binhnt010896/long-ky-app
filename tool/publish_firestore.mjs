#!/usr/bin/env node
// Writes content/eras/*.json, content/people.json, content/periods.json and
// the standalone events from content/events.json into Firestore, live-readable by the app (Cycle K5 —
// apps/mobile/lib/state/firestore_content_source.dart). Each document holds
// the exact canonical JSON text as a single `json` string field — no
// decomposition into native Firestore fields — so this script and the app
// stay exactly in sync with whatever core_domain's models expect, with zero
// duplicated shape logic.
//
// Collections:
//   eras/<slug>            { json, updatedAt }   events inlined, with `order`
//   events/<id>            { json, updatedAt }   standalone events only
//   singletons/people      { json, updatedAt }
//   singletons/periods     { json, updatedAt }
//
// Eras list their events as {ref} items into content/events.json; the `json`
// written here has them inlined (event_inline.mjs — the twin of the Dart
// rule), the same shape the R2 pack carries and every app build parses. The
// 237 events are not one document (they'd exceed Firestore's 1 MiB limit);
// each standalone event is its own small document, and an in-era event rides
// inside its era's document.
//
// Deletes any `eras` doc whose slug is no longer in content/index.json, and
// any `events` doc whose event is no longer standalone (or gone), so a removed
// era/event doesn't linger live in Firestore after it's gone from Git.
// Draft eras (`draft: true`) are never written, same as the R2 pack.
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

import { eventsById, inlineEraEvents, standaloneEventIds } from './event_inline.mjs';

const dryRun = process.argv.includes('--dry-run');

// Resolved from this file, not the working directory: CI and the one-time
// bootstrap both run it from tool/ (where node_modules lives), and a cwd-
// relative `content/` would not exist there.
const contentUrl = (rel) => new URL(`../content/${rel}`, import.meta.url);
const readJson = (rel) => JSON.parse(readFileSync(contentUrl(rel), 'utf8'));
const readText = (rel) => readFileSync(contentUrl(rel), 'utf8');

const index = readJson('index.json');
const rawEras = Object.fromEntries(index.eras.map((slug) => [slug, readJson(`eras/${slug}.json`)]));
const byId = eventsById(readJson('events.json'));
// Listing is judged over *all* eras, drafts included, so an event only a
// draft lists never leaks out as a standalone one.
const standaloneIds = standaloneEventIds(Object.values(rawEras), byId);
const slugs = index.eras.filter((slug) => rawEras[slug].draft !== true);
const canonical = (value) => `${JSON.stringify(value, null, 2)}\n`;

console.log(
  `→ ${dryRun ? '[dry run] would write' : 'content to write:'} ${slugs.length} era(s), ` +
    `${standaloneIds.length} standalone event(s), people.json, periods.json…`,
);

if (dryRun) {
  process.exit(0);
}

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


let batch = db.batch();
let writes = 0;

function set(ref, json) {
  batch.set(ref, { json, updatedAt: FieldValue.serverTimestamp() });
  writes++;
}

for (const slug of slugs) {
  set(db.collection('eras').doc(slug), canonical(inlineEraEvents(rawEras[slug], byId)));
}
for (const id of standaloneIds) {
  set(db.collection('events').doc(id), canonical(byId.get(id)));
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

// …and any events doc that is no longer a standalone event.
const existingEvents = await db.collection('events').listDocuments();
const liveEventIds = new Set(standaloneIds);
for (const doc of existingEvents) {
  if (!liveEventIds.has(doc.id)) {
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
console.log(`✓ wrote ${writes} document(s), removed ${removed} stale doc(s).`);
