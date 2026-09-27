#!/usr/bin/env python
"""One-off: adds English to the already-generated territory_atlas_data.dart
in place, without touching any geometry.

Why a separate script instead of just re-running `gen_atlas.py`: that script
needs the (uncommitted) Natural Earth 10m source file plus `shapely`, neither
of which is available in every environment. This patch only rewrites the
`String` label fields (`name`, `subtitle`, `title`, `boundaryLabel`) to
`LocalizedText(vi: ..., en: ...)` using the same translation table
(`atlas_i18n.py`) that a future `gen_atlas.py` regeneration would use — so the
output is identical either way. All ids, rings, colors and consts are left
byte-for-byte alone.

Usage: python tool/geo/patch_atlas_i18n.py
"""
import os
import re

from atlas_i18n import translate

_HERE = os.path.dirname(os.path.abspath(__file__))
_ROOT = os.path.abspath(os.path.join(_HERE, "..", ".."))
DST = os.path.join(_ROOT, "apps/mobile/lib/screens/prototype/territory_atlas_data.dart")


def esc(s: str) -> str:
    return s.replace("'", r"\'")


def localize(field: str, text: str) -> str:
    en = translate(text)
    if en == text:
        return f"{field}: LocalizedText(vi: '{esc(text)}')"
    return f"{field}: LocalizedText(vi: '{esc(text)}', en: '{esc(en)}')"


def patch_required(match: re.Match, field: str) -> str:
    return localize(field, match.group(1))


def patch_optional(match: re.Match, field: str) -> str:
    if match.group(1) == "null":
        return match.group(0)
    return localize(field, match.group(2))


def main() -> None:
    src = open(DST, encoding="utf-8").read()

    # Required fields: `name: '...'`, `title: '...'`.
    src = re.sub(r"name: '((?:[^'\\]|\\.)*)'",
                 lambda m: patch_required(m, "name"), src)
    src = re.sub(r"title: '((?:[^'\\]|\\.)*)'",
                 lambda m: patch_required(m, "title"), src)

    # Optional fields: `subtitle: null` or `subtitle: '...'`,
    # `boundaryLabel: '...'` (always present when it appears).
    src = re.sub(r"subtitle: (null|'((?:[^'\\]|\\.)*)')",
                 lambda m: patch_optional(m, "subtitle"), src)
    src = re.sub(r"boundaryLabel: '((?:[^'\\]|\\.)*)'",
                 lambda m: patch_required(m, "boundaryLabel"), src)

    # The model types moved from String to LocalizedText — import it.
    if "core_domain/core_domain.dart" not in src:
        src = src.replace(
            "import 'dart:ui';\n",
            "import 'dart:ui';\n\nimport 'package:core_domain/core_domain.dart';\n",
            1,
        )

    open(DST, "w", encoding="utf-8").write(src)
    print("patched", DST)


if __name__ == "__main__":
    main()
