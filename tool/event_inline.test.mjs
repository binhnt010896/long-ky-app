// node --test tool/event_inline.test.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

import { eventsById, inlineEraEvents, standaloneEventIds, withOrderKey } from './event_inline.mjs';

const read = (rel) => JSON.parse(readFileSync(new URL(`../content/${rel}`, import.meta.url), 'utf8'));
const index = read('index.json');
const registry = read('events.json');
const byId = eventsById(registry);
const eras = index.eras.map((slug) => read(`eras/${slug}.json`));

test('order goes right before kind', () => {
  const keys = Object.keys(withOrderKey({ id: 'x', title: 't', kind: 'legend' }, 3));
  assert.deepEqual(keys, ['id', 'title', 'order', 'kind']);
});

test('every real era inlines: order = position, ids = refs, no refs left', () => {
  for (const era of eras) {
    const out = inlineEraEvents(era, byId);
    assert.deepEqual(out.events.map((e) => e.order), out.events.map((_, i) => i), era.slug);
    assert.deepEqual(out.events.map((e) => e.id), era.events.map((r) => r.ref), era.slug);
    assert.ok(out.events.every((e) => !('ref' in e)), era.slug);
  }
});

test('an era with nothing to inline is returned as is', () => {
  const inlined = inlineEraEvents(eras[0], byId);
  assert.equal(inlineEraEvents(inlined, byId), inlined);
});

test('an unknown ref is an error naming the id', () => {
  assert.throws(() => inlineEraEvents({ slug: 'e', events: [{ ref: 'gone' }] }, byId), /gone/);
});

test('the real content has no standalone events yet', () => {
  assert.deepEqual(standaloneEventIds(eras, byId), []);
});

test('an event no era lists is standalone', () => {
  const extra = new Map(byId).set('lone', { id: 'lone' });
  assert.deepEqual(standaloneEventIds(eras, extra), ['lone']);
});
