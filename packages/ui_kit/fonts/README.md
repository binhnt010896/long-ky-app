# Bundled fonts

Both families are bundled (not runtime-fetched) so every Vietnamese diacritic
renders offline. Family names must match `VSType.familyDisplay` / `familyBody`.

| Family | Files | Source | License |
| --- | --- | --- | --- |
| **Playfair Display** | `PlayfairDisplay-Variable.ttf`, `PlayfairDisplay-Italic-Variable.ttf` (variable `wght` 400–900) | [google/fonts › playfairdisplay](https://github.com/google/fonts/tree/main/ofl/playfairdisplay) | SIL Open Font License 1.1 |
| **Be Vietnam Pro** | `BeVietnamPro-{ExtraLight,Light,Regular,Medium,SemiBold}.ttf` | [google/fonts › bevietnampro](https://github.com/google/fonts/tree/main/ofl/bevietnampro) | SIL Open Font License 1.1 |

Playfair is a variable font; `VSType._display` sets the exact weight via
`fontVariations: [FontVariation('wght', …)]`, so one roman + one italic file
covers the 500/600/700 weights the design uses.

> Grant/compliance note: OFL 1.1 permits bundling and redistribution. Keep the
> upstream `OFL.txt` for each family alongside these binaries before shipping.
