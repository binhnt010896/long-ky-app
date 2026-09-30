// The JS twin of packages/core_domain/lib/src/event_inlining.dart — the same
// rule, so what reaches Firestore is byte-for-byte the shape the R2 pack
// (tool/build_content_pack.dart) and every installed app already parse: an
// era's `{ref}` items replaced by the full event plus `order` = list position,
// with `order` placed right before `kind`, where authored events keep it.

export function withOrderKey(event, order) {
  const out = {};
  let placed = false;
  for (const [k, v] of Object.entries(event)) {
    if (k === 'order') continue;
    if (k === 'kind' && !placed) {
      out.order = order;
      placed = true;
    }
    out[k] = v;
  }
  if (!placed) out.order = order;
  return out;
}

export const isEventRef = (item) =>
  item !== null && typeof item === 'object' && 'ref' in item;

export function eventsById(registry) {
  const map = new Map();
  for (const e of registry.events) {
    if (map.has(e.id)) throw new Error(`duplicate event id ${e.id}`);
    map.set(e.id, e);
  }
  return map;
}

export function inlineEraEvents(era, byId) {
  if (!era.events.some(isEventRef)) return era;
  const events = era.events.map((item, i) => {
    if (!isEventRef(item)) return item;
    const event = byId.get(item.ref);
    if (!event) throw new Error(`era ${era.slug}: unknown event ref ${item.ref}`);
    return withOrderKey(event, i);
  });
  return { ...era, events };
}

/** Ids of registry events no era lists (drafts included), in registry order. */
export function standaloneEventIds(rawEras, byId) {
  const used = new Set();
  for (const era of rawEras) {
    for (const item of era.events ?? []) used.add(isEventRef(item) ? item.ref : item.id);
  }
  return [...byId.keys()].filter((id) => !used.has(id));
}
