#!/usr/bin/env python
"""Rebuild the territory atlas on REAL Natural Earth coastlines.

Technique: the coastline is fixed (real ne10m country geometry); only the
internal political borders vary per era. Vietnamese polities are cut from the
real Vietnam landmass by the Nam tiến frontier latitude (sourced below);
neighbours are the real modern countries, relabelled per era as dim context.
This replaces the coarse, overextended historical-basemaps polygons.

Frontier latitudes (Đại Việt / Champa border marching south — ĐVSKTT & sử):
  17.9°N Hoành Sơn/Đèo Ngang (Lý, after 1069)   16.2°N Hải Vân (Trần, 1306 Thuận Hóa)
  13.8°N Cù Mông/Bình Định (Lê, 1471)            ~11°N  Bình Thuận (1697, end of Champa)
  17.6°N Sông Gianh (Trịnh–Nguyễn)               Mekong delta: Khmer until ~1700.
"""
#
# Usage:  python tool/geo/gen_atlas.py [path/to/ne_10m_admin_0_countries.geojson]
#
# Requires: shapely (+ Pillow only if PREVIEW=1). The Natural Earth 10m
# admin-0 countries file is public domain but NOT committed (it is large); pass
# its path, or set NE10M, or drop it at tool/geo/ne10m.json.
import json, math, os, sys
from shapely.geometry import shape, box
from shapely.ops import unary_union

_HERE = os.path.dirname(os.path.abspath(__file__))
_ROOT = os.path.abspath(os.path.join(_HERE, "..", ".."))
NE = (sys.argv[1] if len(sys.argv) > 1 else
      os.environ.get("NE10M", os.path.join(_HERE, "ne10m.json")))
DST = os.path.join(_ROOT, "apps/mobile/lib/screens/prototype/territory_atlas_data.dart")

BBOX = box(99, 5, 117, 24)
SIMPLIFY = 0.02        # degrees (~2 km) — crisp coast, modest point count

# ---- load countries ----
raw = json.load(open(NE))
LAND = {}
for f in raw["features"]:
    adm = f["properties"].get("ADMIN")
    if adm in ("Vietnam", "China", "Cambodia", "Thailand", "Laos", "Myanmar"):
        g = shape(f["geometry"])
        if not g.is_valid:
            g = g.buffer(0)
        LAND[adm] = g.intersection(BBOX).simplify(SIMPLIFY, preserve_topology=True)

# Vietnam mainland = its largest polygon (Mekong delta included); the small
# offshore polygons (Phú Quốc, Côn Đảo…) are handled separately.
def polys(geom):
    if geom.is_empty:
        return []
    return list(geom.geoms) if geom.geom_type == "MultiPolygon" else [geom]

VN_ALL = polys(LAND["Vietnam"])
VN_MAIN = max(VN_ALL, key=lambda p: p.area)

def CN():  return LAND["China"]
def KH():  return LAND["Cambodia"]
def TH():  return LAND["Thailand"]
def LA():  return LAND["Laos"]
def MM():  return LAND["Myanmar"]

def VN(south, north):
    """Slice the real Vietnam mainland to a latitude band."""
    return VN_MAIN.intersection(box(99, south, 117, north))

def MEKONG():
    """The far-south Mekong tip — Khmer/Funan land before the Nguyễn Nam tiến."""
    return VN_MAIN.intersection(box(99, 5, 117, 11))

# ---- projection: lat-corrected equirectangular, normalized 0..1, y-flipped ----
def proj(lon, lat):
    return (round((lon - 99) / 18.0, 4), round(1 - (lat - 5) / 19.0, 4))

K = math.cos(math.radians(14.5))
ASPECT = round(18 * K / 19, 4)  # 0.9172

def rings(geom, min_area=2.5e-4):
    out = []
    for p in polys(geom):
        xy = [proj(x, y) for x, y in p.exterior.coords]
        # drop consecutive duplicates
        ded = [xy[0]]
        for q in xy[1:]:
            if q != ded[-1]:
                ded.append(q)
        if len(ded) < 4:
            continue
        # shoelace area in normalized space
        a = abs(sum(ded[i][0]*ded[i+1][1] - ded[i+1][0]*ded[i][1]
                    for i in range(len(ded)-1))) / 2
        if a >= min_area:
            out.append(ded)
    return out

def island(centroid_lon, centroid_lat, tol=0.004):
    """Extract the small VN offshore polygon nearest a point (Phú Quốc / Côn Đảo)."""
    best = min(VN_ALL, key=lambda p: p.centroid.distance(
        shape({"type": "Point", "coordinates": [centroid_lon, centroid_lat]})))
    return rings(best.simplify(tol, preserve_topology=True), min_area=0)

def centroid_norm(rs):
    pts = [q for r in rs for q in r]
    return (round(sum(p[0] for p in pts)/len(pts), 4),
            round(sum(p[1] for p in pts)/len(pts), 4))

# palette (packed 0xAARRGGBB)
RED, GOLD, TEAL, PURPLE = 0xFF7A4B45, 0xFFB5793F, 0xFF4F7A70, 0xFF6D5A7A
THAI, LAO, BURMA, TRINH = 0xFF8A5A4A, 0xFF6B7A55, 0xFF7A7150, 0xFF5F6B86
TAYSON, FUNAN = 0xFFA85535, 0xFF5F8A72

# Shared neighbour geometries — identical every era, so emit once as consts and
# reference them (dim context → simplified harder to keep the file small).
NEI = 0.05
CONSTS = {
    "kCN": CN().simplify(NEI, preserve_topology=True),
    "kKH": KH().simplify(NEI, preserve_topology=True),
    "kKHm": unary_union([KH(), MEKONG()]).simplify(NEI, preserve_topology=True),
    "kTH": TH().simplify(NEI, preserve_topology=True),
    "kLA": LA().simplify(NEI, preserve_topology=True),
    "kMM": MM().simplify(NEI, preserve_topology=True),
}

# ---- per-era spec: (id, name, subtitle, color, bright, geometry, label?) ----
def R(id, name, sub, color, bright, geom=None, label=True, const=None):
    return dict(id=id, name=name, sub=sub, color=color, bright=bright,
                geom=geom, label=label, const=const)

def khmer(name, sub, with_mekong):
    return R("khmer", name, sub, PURPLE, False, const="kKHm" if with_mekong else "kKH")

def china(name, sub=None):
    return R("china", name, sub, RED, False, const="kCN")

def ctx():  # dim context lands with no on-map label
    return [R("thai", "Xiêm", None, THAI, False, const="kTH", label=False),
            R("lao", "Ai Lao", None, LAO, False, const="kLA", label=False),
            R("burma", "Miến Điện", None, BURMA, False, const="kMM", label=False)]

YEARS = {
 200:  dict(regs=[
        R("giao-chi", "Giao Chỉ", "Bắc thuộc", RED, True, VN(15.5, 24)),
        R("lam-ap", "Lâm Ấp", "Chăm Pa sơ khai", GOLD, True, VN(11, 15.5)),
        china("Nhà Hán", "Bắc thuộc"),
        R("funan", "Phù Nam", None, FUNAN, False, const="kKHm"),
        *ctx()]),
 500:  dict(regs=[
        R("giao-chau", "Giao Châu", "Bắc thuộc", RED, True, VN(17, 24)),
        R("champa", "Chăm Pa", "Lâm Ấp", GOLD, True, VN(11, 17)),
        china("Nhà Tề", "Bắc thuộc"),
        R("funan", "Phù Nam", None, FUNAN, False, const="kKHm"),
        *ctx()]),
 900:  dict(regs=[
        R("tinh-hai", "Tĩnh Hải quân", "Bắc thuộc (nhà Đường)", RED, True, VN(17.9, 24)),
        R("champa", "Chăm Pa", "Chiêm Thành", GOLD, True, VN(11, 17.9)),
        china("Nhà Đường", "Bắc thuộc"),
        khmer("Chân Lạp", "Khmer", True),
        *ctx()]),
 1100: dict(regs=[
        R("dai-viet", "Đại Việt", "Nhà Lý", TEAL, True, VN(17.5, 24)),
        R("champa", "Chăm Pa", "Chiêm Thành", GOLD, True, VN(11, 17.5)),
        china("Nhà Tống"),
        khmer("Đế quốc Khmer", "Chân Lạp", True),
        *ctx()]),
 1300: dict(regs=[
        R("dai-viet", "Đại Việt", "Nhà Trần", TEAL, True, VN(16.2, 24)),
        R("champa", "Chăm Pa", "Chiêm Thành", GOLD, True, VN(11, 16.2)),
        china("Nhà Nguyên"),
        khmer("Đế quốc Khmer", "Chân Lạp", True),
        *ctx()]),
 1500: dict(regs=[
        R("dai-viet", "Đại Việt", "Nhà Lê sơ", TEAL, True, VN(13.8, 24)),
        R("champa", "Chăm Pa", "Panduranga", GOLD, True, VN(11, 13.8)),
        china("Nhà Minh"),
        khmer("Chân Lạp", "Cao Miên", True),
        *ctx()]),
 1650: dict(regs=[
        R("dang-ngoai", "Đàng Ngoài", "vua Lê · chúa Trịnh", TRINH, True, VN(17.6, 24)),
        R("dang-trong", "Đàng Trong", "chúa Nguyễn", TEAL, True, VN(12, 17.6)),
        R("champa", "Chăm Pa", "Panduranga", GOLD, True, VN(11, 12)),
        china("Nhà Thanh"),
        khmer("Chân Lạp", "Cao Miên", True),
        *ctx()],
        boundary=(17.6, 106.0, 108.8), boundary_label="Sông Gianh"),
 1800: dict(regs=[
        R("tay-son", "Tây Sơn", "Cảnh Thịnh", TAYSON, True, VN(14.5, 24)),
        R("nguyen", "Nguyễn", "Nguyễn Ánh · Gia Định", TEAL, True, VN(5, 14.5)),
        china("Nhà Thanh"),
        khmer("Cao Miên", None, False),
        *ctx()],
        boundary=(14.5, 108.2, 109.2), boundary_label="Tây Sơn – Nguyễn"),
 1880: dict(regs=[
        R("dai-nam", "Đại Nam", "Nhà Nguyễn", TEAL, True, VN(5, 24)),
        china("Nhà Thanh"),
        khmer("Cao Miên", "Pháp bảo hộ", False),
        *ctx()]),
 2010: dict(regs=[
        R("vietnam", "Việt Nam", None, TEAL, True, VN(5, 24)),
        china("Trung Quốc"),
        khmer("Cam-pu-chia", None, False),
        *ctx()]),
}

# ---- emit Dart ----
def fmt_offsets(rs):
    parts = []
    for r in rs:
        parts.append("[" + ", ".join(f"Offset({x},{y})" for x, y in r) + "]")
    return "[" + ", ".join(parts) + "]"

lines = []
lines.append("// GENERATED — do not edit. Source: Natural Earth 10m (public domain).")
lines.append("// Real coastlines; internal borders authored per era from ĐVSKTT/chính sử")
lines.append("// (the Nam tiến frontier as a marching latitude). See tool/geo/gen_atlas.py.")
lines.append("import 'dart:ui';")
lines.append("import 'territory_atlas_model.dart';")
lines.append("")
lines.append(f"const double kAtlasAspect = {ASPECT};")
lines.append("")

pq = island(103.97, 10.28)
cd = island(106.60, 8.68)
lines.append(f"const List<List<Offset>> kPhuQuoc = {fmt_offsets(pq)};")
lines.append(f"const List<List<Offset>> kConDao = {fmt_offsets(cd)};")
lines.append("")
lines.append("/// Present-day Vietnam mainland — the dashed reference outline.")
lines.append(f"const List<List<Offset>> kModernVietnam = {fmt_offsets(rings(VN_MAIN))};")
lines.append("")

# Shared neighbour geometries, emitted once and referenced by every era.
CONST_RINGS = {name: rings(g) for name, g in CONSTS.items()}
for name, rs in CONST_RINGS.items():
    lines.append(f"const List<List<Offset>> {name} = {fmt_offsets(rs)};")
lines.append("")
lines.append("const List<AtlasYear> kAtlas = <AtlasYear>[")

for yr in sorted(YEARS):
    spec = YEARS[yr]
    b = spec.get("boundary")
    bl = spec.get("boundary_label")
    lines.append("  AtlasYear(year: {}, mapAspect: kAtlasAspect,".format(yr))
    if b:
        lat, lon0, lon1 = b
        p0 = proj(lon0, lat); p1 = proj(lon1, lat)
        lines.append(f"    boundary: <Offset>[Offset({p0[0]},{p0[1]}), Offset({p1[0]},{p1[1]})],")
        lines.append(f"    boundaryLabel: '{bl}',")
    lines.append("    regions: <AtlasRegion>[")
    for r in spec["regs"]:
        if r["const"]:
            rs = CONST_RINGS[r["const"]]
            rg = r["const"]
        else:
            rs = rings(r["geom"])
            rg = fmt_offsets(rs)
        if not rs:
            continue
        lab = "null"
        if r["label"]:
            lab = "Offset({},{})".format(*centroid_norm(rs))
        sub = "null" if r["sub"] is None else "'{}'".format(r["sub"])
        lines.append(
            "      AtlasRegion(id: '{y}-{id}', name: '{n}', subtitle: {s}, "
            "color: 0x{c:08X}, bright: {b}, labelAt: {lab}, rings: {rg}),".format(
                y=yr, id=r["id"], n=r["name"], s=sub, c=r["color"],
                b="true" if r["bright"] else "false", lab=lab, rg=rg))
    lines.append("    ]),")
lines.append("];")

open(DST, "w").write("\n".join(lines) + "\n")
print("wrote", DST)

# ---- render a verification preview straight from the geometry ----
def render_preview():
    from PIL import Image, ImageDraw
    W = 440; H = int(W / ASPECT)
    def argb(c): return ((c >> 16) & 255, (c >> 8) & 255, c & 255, (c >> 24) & 255)
    def pxp(p): return (p[0] * W, p[1] * H)
    modern = rings(VN_MAIN)
    def draw(yr, title):
        img = Image.new("RGBA", (W, H), (12, 23, 20, 255)); d = ImageDraw.Draw(img, "RGBA")
        regs = YEARS[yr]["regs"]
        for r in sorted(regs, key=lambda r: r["bright"]):
            rs = CONST_RINGS[r["const"]] if r["const"] else rings(r["geom"])
            col = argb(r["color"]); al = 200 if r["bright"] else 80
            for ring in rs:
                d.polygon([pxp(p) for p in ring], fill=(col[0], col[1], col[2], al),
                          outline=(198, 160, 74, 150))
        for ring in modern:
            pts = [pxp(p) for p in ring] + [pxp(ring[0])]
            for i in range(len(pts) - 1):
                a, b = pts[i], pts[i + 1]; seg = math.hypot(b[0]-a[0], b[1]-a[1]); n = max(1, int(seg/5))
                for k in range(n):
                    if k % 2 == 0:
                        t0 = k/n; t1 = (k+0.6)/n
                        d.line([(a[0]+(b[0]-a[0])*t0, a[1]+(b[1]-a[1])*t0),
                                (a[0]+(b[0]-a[0])*t1, a[1]+(b[1]-a[1])*t1)], fill=(240,205,120,205), width=1)
        for r in regs:
            if r["label"]:
                rs = CONST_RINGS[r["const"]] if r["const"] else rings(r["geom"])
                cx, cy = centroid_norm(rs)
                d.text((cx*W - len(r["name"])*3, cy*H - 4), r["name"], fill=(235,235,225,255))
        d.text((8, 8), title, fill=(240, 205, 120, 255))
        return img
    panels = [(200,"200 Han"),(900,"900 Duong"),(1100,"1100 Ly"),
              (1300,"1300 Tran"),(1650,"1650 Trinh-Nguyen"),(1800,"1800 TaySon-Nguyen")]
    imgs = [draw(y, t) for y, t in panels]; gap = 10
    sheet = Image.new("RGBA", (W*6+gap*7, H+gap*2), (8, 15, 13, 255))
    for i, im in enumerate(imgs): sheet.paste(im, (gap+i*(W+gap), gap), im)
    out = os.path.join(_HERE, "rebuild_preview.png")
    sheet.convert("RGB").save(out); print("preview:", out)

if os.environ.get("PREVIEW") == "1":
    render_preview()
print("years:", sorted(YEARS))
print("modern VN rings pts:", sum(len(r) for r in rings(VN_MAIN)))
print("phu quoc pts:", sum(len(r) for r in pq), "con dao pts:", sum(len(r) for r in cd))
