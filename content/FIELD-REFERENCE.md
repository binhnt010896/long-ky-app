# Content field reference

The contract for `content/eras/*.json`. Enforced by
[`era.schema.json`](era.schema.json) via `melos run validate:content`, and
mirrored by the `core_domain` models. **Vietnamese (`vi`) is canonical and
required with full diacritics; English (`en`) is an optional toggle.**

## Conventions

- **LocalizedText** — every human string is `{ "vi": "…", "en": "…" }`. `vi` is
  required; omit `en` to fall back to `vi` at runtime (never a stripped-diacritic
  form).
- **hexColor** — `#RRGGBB`, lowercase.
- **Years** — integers; **negative = BCE (TCN)**. `null` for pure legend.
- **Filename = slug.** `hong-bang-van-lang.json` must declare
  `"slug": "hong-bang-van-lang"`, and the slug must appear in
  [`index.json`](index.json).

## Era (top level)

| Field | Type | Req | Notes |
| --- | --- | --- | --- |
| `schemaVersion` | int (`1`) | ✓ | Contract version. |
| `id`, `slug` | string | ✓ | `slug` is kebab-case, = filename. |
| `order` | int ≥ 0 | ✓ | Position in the era stack / global timeline. |
| `title`, `kicker`, `subtitle` | LocalizedText | ✓ | Hero strings. |
| `yearRange` | `{ display, startYear?, endYear? }` | ✓ | `display` shown; year ints for scrubbing. |
| `palette` | `{ accent, particle?, scene? }` | ✓ | `accent` drives the sơn mài scene; `scene` overrides the derived gradient. |
| `cover` | AssetRef | — | Home-stack card art. |
| `scene.layers[]` | AssetRef[] | — | Parallax slots, **back → front** (ascending `depth`). |
| `primarySource` | Citation | ✓ | The single chronicle for the era. |
| `events[]` | HistoryEvent[] (≥1) | ✓ | Sorted by `order` on load. |

## HistoryEvent

| Field | Type | Req | Notes |
| --- | --- | --- | --- |
| `id` | string | ✓ | Stable. |
| `slug` | string | — | Kebab-case. |
| `order` | int ≥ 0 | ✓ | Authoritative sequence in the era. |
| `kind` | `legend` \| `semi-historical` \| `historical` | ✓ | How strongly the UI asserts the claim. |
| `year` | `{ display, value?, approximate? }` | ✓ | `value` null for legend; `approximate` = circa (≈). |
| `title`, `summary` | LocalizedText | ✓ | `summary` is the one-line timeline subtitle. |
| `body` | LocalizedText | — | Long-form detail text. |
| `pullQuote` | `{ text, attribution? }` | — | The italic chronicle quote. |
| `hero` | AssetRef | — | Detail-screen hero slot. |
| `citation` | Citation | ✓ | **Rendered visibly on every event.** |

## Citation

`{ work (req), section?, author?, url?, note? }` — `work` is a plain string
(proper noun); `section`/`note` are LocalizedText.

## AssetRef (tier-aware)

`{ id, type, role?, depth?, flagship?, reduced?, placeholder?, caption?, credit? }`

- `type`: `image` \| `rive` \| `particles` \| `gradient`.
- `role`: `cover` \| `hero` \| `sky` \| `mid` \| `foreground` \| `overlay` \| `particles`.
- `depth`: `0` (far) → `1` (near), for parallax.
- `flagship` may be Rive/animated; `reduced` is the static fallback; `placeholder`
  names a built-in stand-in (e.g. `era-scene`) used until real art lands. A ref
  with neither `flagship` nor `reduced` renders its placeholder.
