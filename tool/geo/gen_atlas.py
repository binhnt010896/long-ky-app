#!/usr/bin/env python
"""Generate the per-era territory atlas on REAL Natural Earth coastlines.

Technique: the coastline is fixed (real ne10m country geometry); only the
internal political borders vary. Snapshots are keyed to ERA SLUGS (dynasties),
not round years. Vietnamese polities are cut from the real Vietnam landmass by
the Nam tiến frontier latitude (sourced below); split eras carry rival states;
Minh Mạng / French eras carry protectorate (claim) regions in a faded tone.

Frontier latitudes (Đại Việt / Champa border marching south — ĐVSKTT & chính sử):
  ~18°N Đèo Ngang (Đinh/Tiền Lê/Ngô)     17.9°N Hoành Sơn (Lý, after 1069)
  16.2°N Hải Vân (Trần, 1306 Thuận Hóa)  13.3°N Phú Yên (Lê Thánh Tông, 1471)
  17.6°N Sông Gianh (Trịnh–Nguyễn)       Mekong delta: Khmer until ~1700.

Usage:  python tool/geo/gen_atlas.py [path/to/ne_10m_admin_0_countries.geojson]
Requires shapely (+ Pillow if PREVIEW=1). ne10m file is public domain, not
committed — pass its path, set NE10M, or drop it at tool/geo/ne10m.json.
"""
import json, math, os, sys
from shapely.geometry import shape, box
from shapely.ops import unary_union

_HERE = os.path.dirname(os.path.abspath(__file__))
_ROOT = os.path.abspath(os.path.join(_HERE, "..", ".."))
NE = (sys.argv[1] if len(sys.argv) > 1 else
      os.environ.get("NE10M", os.path.join(_HERE, "ne10m.json")))
DST = os.path.join(_ROOT, "apps/mobile/lib/screens/prototype/territory_atlas_data.dart")

BBOX = box(99, 5, 117, 24)
SIMPLIFY = 0.02

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
    return VN_MAIN.intersection(box(99, south, 117, north))

def MEKONG():
    return VN_MAIN.intersection(box(99, 5, 117, 11))

def SOUTH_CHINA():
    """Southern China within view — Lưỡng Quảng, for the Nam Việt north bulge."""
    return CN().intersection(box(106, 20, 117, 24))

def LAOS_EAST():
    """Eastern Laos (Trấn Ninh / Xiêng Khouang) — Minh Mạng protectorate."""
    return LA().intersection(box(102.5, 16.5, 108, 20.5))

# ---- projection: lat-corrected equirectangular, normalized 0..1, y-flipped ----
def proj(lon, lat):
    return (round((lon - 99) / 18.0, 4), round(1 - (lat - 5) / 19.0, 4))

K = math.cos(math.radians(14.5))
ASPECT = round(18 * K / 19, 4)  # 0.9172

def rings(geom, min_area=2.5e-4):
    out = []
    for p in polys(geom):
        xy = [proj(x, y) for x, y in p.exterior.coords]
        ded = [xy[0]]
        for q in xy[1:]:
            if q != ded[-1]:
                ded.append(q)
        if len(ded) < 4:
            continue
        a = abs(sum(ded[i][0]*ded[i+1][1] - ded[i+1][0]*ded[i][1]
                    for i in range(len(ded)-1))) / 2
        if a >= min_area:
            out.append(ded)
    return out

def island(clon, clat, tol=0.004):
    best = min(VN_ALL, key=lambda p: p.centroid.distance(
        shape({"type": "Point", "coordinates": [clon, clat]})))
    return rings(best.simplify(tol, preserve_topology=True), min_area=0)

def centroid_norm(rs):
    pts = [q for r in rs for q in r]
    return (round(sum(p[0] for p in pts)/len(pts), 4),
            round(sum(p[1] for p in pts)/len(pts), 4))

# palette (packed 0xAARRGGBB)
RED, GOLD, TEAL, PURPLE = 0xFF7A4B45, 0xFFB5793F, 0xFF4F7A70, 0xFF6D5A7A
THAI, LAO, BURMA, TRINH = 0xFF8A5A4A, 0xFF6B7A55, 0xFF7A7150, 0xFF5F6B86
TAYSON, FUNAN, MAC, PHAP = 0xFFA85535, 0xFF5F8A72, 0xFF8C4A52, 0xFF41618C

# Shared neighbour geometries — identical every era, emitted once as consts.
NEI = 0.05
CONSTS = {
    "kCN": CN().simplify(NEI, preserve_topology=True),
    "kKH": KH().simplify(NEI, preserve_topology=True),
    "kKHm": unary_union([KH(), MEKONG()]).simplify(NEI, preserve_topology=True),
    "kTH": TH().simplify(NEI, preserve_topology=True),
    "kLA": LA().simplify(NEI, preserve_topology=True),
    "kMM": MM().simplify(NEI, preserve_topology=True),
}

def R(id, name, sub, color, role, geom=None, label=True, const=None):
    return dict(id=id, name=name, sub=sub, color=color, role=role,
                geom=geom, label=label, const=const)

# role helpers
def core(id, name, sub, color, geom):     return R(id, name, sub, color, "core", geom)
def rival(id, name, sub, color, geom):    return R(id, name, sub, color, "rival", geom)
def prot(id, name, sub, color, geom):     return R(id, name, sub, color, "protectorate", geom)

def china(name="Trung Quốc", sub=None):
    return R("china", name, sub, RED, "neighbour", const="kCN")
def khmer(name, sub, mekong):
    return R("khmer", name, sub, PURPLE, "neighbour", const="kKHm" if mekong else "kKH")
def ctx():  # dim, unlabeled context lands
    return [R("thai", "Xiêm", None, THAI, "neighbour", const="kTH", label=False),
            R("lao", "Ai Lao", None, LAO, "neighbour", const="kLA", label=False),
            R("burma", "Miến Điện", None, BURMA, "neighbour", const="kMM", label=False)]

def champa(south, north, sub="Chiêm Thành"):
    return R("champa", "Chăm Pa", sub, GOLD, "neighbour", VN(south, north))

# ---- snapshots (dynasty-keyed) ----
def S(id, title, sub, anchor, eras, regs, boundary=None, boundary_label=None):
    return dict(id=id, title=title, sub=sub, anchor=anchor, eras=eras,
                regs=regs, boundary=boundary, boundary_label=boundary_label)

# Sông Gianh dashed divider (lat, lon0, lon1)
GIANH = (17.6, 106.0, 108.8)

SNAPSHOTS = [
    S("van-lang", "Văn Lang", "Hồng Bàng", -500, ["hong-bang-van-lang"], [
        core("van-lang", "Văn Lang", "Vua Hùng", TEAL, VN(18, 24)),
        china(), *ctx()]),
    S("au-lac", "Âu Lạc", "An Dương Vương", -257, ["au-lac"], [
        core("au-lac", "Âu Lạc", "An Dương Vương", TEAL, VN(18, 24)),
        china(), *ctx()]),
    S("nam-viet", "Nam Việt", "Nhà Triệu", -180, ["nha-trieu"], [
        core("nam-viet", "Nam Việt", "Triệu Đà · Lưỡng Quảng",
             TEAL, unary_union([VN(17, 24), SOUTH_CHINA()])),
        R("funan", "Phù Nam", None, FUNAN, "neighbour", const="kKHm"),
        *ctx()]),
    S("hai-ba-trung", "Trưng Vương", "Khởi nghĩa Hai Bà Trưng", 40, ["hai-ba-trung"], [
        core("trung", "Trưng Vương", "Mê Linh", TEAL, VN(16, 24)),
        R("nhat-nam", "Nhật Nam", "Nhà Hán", RED, "neighbour", VN(11, 16)),
        R("funan", "Phù Nam", None, FUNAN, "neighbour", const="kKHm"),
        china("Nhà Hán", "Bắc thuộc"), *ctx()]),
    S("ba-trieu", "Bắc thuộc", "Khởi nghĩa Bà Triệu", 248, ["ba-trieu"], [
        core("giao-chau", "Giao Châu", "Bắc thuộc (Đông Ngô)", RED, VN(17, 24)),
        champa(11, 17, "Lâm Ấp"), china("Đông Ngô", "Bắc thuộc"),
        khmer("Phù Nam", None, True), *ctx()]),
    S("van-xuan", "Vạn Xuân", "Lý Nam Đế", 550, ["van-xuan"], [
        core("van-xuan", "Vạn Xuân", "Lý Nam Đế", TEAL, VN(16, 24)),
        champa(11, 16), china("Nhà Lương", "Bắc thuộc"),
        khmer("Chân Lạp", "Khmer", True), *ctx()]),
    S("bac-thuoc", "Bắc thuộc", "Nhà Đường đô hộ", 750, ["mai-hac-de", "phung-hung"], [
        core("giao-chau", "An Nam đô hộ phủ", "Bắc thuộc", RED, VN(17, 24)),
        champa(11, 17), china("Nhà Đường", "Bắc thuộc"),
        khmer("Chân Lạp", "Khmer", True), *ctx()]),
    S("tu-chu", "Tự chủ", "Họ Khúc", 910, ["khuc-thua-du"], [
        core("tinh-hai", "Tĩnh Hải quân", "Khúc Thừa Dụ", TEAL, VN(18, 24)),
        champa(11, 18), china("Nhà Đường"), khmer("Chân Lạp", "Khmer", True), *ctx()]),
    S("ngo", "Nhà Ngô", "Ngô Quyền", 940, ["ngo-quyen"], [
        core("ngo", "Tĩnh Hải quân", "Ngô Quyền", TEAL, VN(18, 24)),
        champa(11, 18), china("Nam Hán"), khmer("Chân Lạp", "Khmer", True), *ctx()]),
    S("dinh", "Nhà Đinh", "Đại Cồ Việt", 968, ["dinh-tien-hoang"], [
        core("dinh", "Đại Cồ Việt", "Đinh Tiên Hoàng", TEAL, VN(18, 24)),
        champa(11, 18), china("Nhà Tống"), khmer("Chân Lạp", "Khmer", True), *ctx()]),
    S("tien-le", "Tiền Lê", "Lê Đại Hành", 985, ["tien-le"], [
        core("tien-le", "Đại Cồ Việt", "Lê Đại Hành", TEAL, VN(18, 24)),
        champa(11, 18), china("Nhà Tống"), khmer("Chân Lạp", "Khmer", True), *ctx()]),
    S("ly", "Nhà Lý", "Đại Việt", 1075, ["ly-thai-to", "ly-thai-tong", "ly-nhan-tong"], [
        core("ly", "Đại Việt", "Nhà Lý", TEAL, VN(17.9, 24)),
        champa(11, 17.9), china("Nhà Tống"),
        khmer("Đế quốc Khmer", "Chân Lạp", True), *ctx()]),
    S("tran", "Nhà Trần", "Đại Việt", 1300, ["tran-thai-tong", "tran-hung-dao"], [
        core("tran", "Đại Việt", "Nhà Trần", TEAL, VN(16.2, 24)),
        champa(11, 16.2), china("Nhà Nguyên"),
        khmer("Đế quốc Khmer", "Chân Lạp", True), *ctx()]),
    S("le-loi", "Lê sơ", "Lê Lợi", 1428, ["le-loi"], [
        core("le-so", "Đại Việt", "Lê Thái Tổ", TEAL, VN(16.2, 24)),
        champa(11, 16.2), china("Nhà Minh"),
        khmer("Chân Lạp", "Cao Miên", True), *ctx()]),
    S("le-thanh-tong", "Lê Thánh Tông", "Hồng Đức", 1480, ["le-thanh-tong"], [
        core("le-thanh-tong", "Đại Việt", "Lê Thánh Tông", TEAL, VN(13.3, 24)),
        champa(11, 13.3, "Panduranga"), china("Nhà Minh"),
        khmer("Chân Lạp", "Cao Miên", True), *ctx()]),
    S("nam-bac-trieu", "Nam – Bắc triều", "Mạc vs Lê–Trịnh", 1560, ["nam-bac-trieu"], [
        rival("mac", "Nhà Mạc", "Bắc triều", MAC, VN(20, 24)),
        rival("le-trinh", "Lê – Trịnh", "Nam triều", TRINH, VN(13.3, 20)),
        champa(11, 13.3, "Panduranga"), china("Nhà Minh"),
        khmer("Chân Lạp", "Cao Miên", True), *ctx()]),
    S("trinh-nguyen", "Trịnh – Nguyễn", "Đàng Ngoài & Đàng Trong", 1650, ["trinh-nguyen"], [
        rival("dang-ngoai", "Đàng Ngoài", "vua Lê · chúa Trịnh", TRINH, VN(17.6, 24)),
        rival("dang-trong", "Đàng Trong", "chúa Nguyễn", TEAL, VN(12, 17.6)),
        champa(11, 12, "Panduranga"), china("Nhà Thanh"),
        khmer("Chân Lạp", "Cao Miên", True), *ctx()],
      boundary=GIANH, boundary_label="Sông Gianh"),
    S("tay-son", "Tây Sơn", "Nguyễn Huệ vs Nguyễn Ánh", 1788, ["tay-son"], [
        rival("tay-son", "Tây Sơn", "Nguyễn Huệ", TAYSON, VN(11.5, 24)),
        rival("nguyen-anh", "Nguyễn Ánh", "Gia Định", TEAL, VN(5, 11.5)),
        china("Nhà Thanh"), khmer("Cao Miên", None, False), *ctx()]),
    S("gia-long", "Nhà Nguyễn", "Gia Long thống nhất", 1805, ["gia-long"], [
        core("viet-nam", "Việt Nam", "Gia Long", TEAL, VN(5, 24)),
        china("Nhà Thanh"), khmer("Cao Miên", None, False), *ctx()]),
    S("minh-mang", "Minh Mạng", "Đại Nam cực thịnh", 1835, ["minh-mang"], [
        core("dai-nam", "Đại Nam", "Minh Mạng", TEAL, VN(5, 24)),
        prot("tran-tay", "Trấn Tây · Ai Lao", "Nguyễn bảo hộ", TEAL,
             unary_union([KH(), LAOS_EAST()])),
        china("Nhà Thanh"), *ctx()]),
    S("thieu-tri", "Thiệu Trị", "Đại Nam", 1845, ["thieu-tri"], [
        core("dai-nam", "Đại Nam", "Thiệu Trị", TEAL, VN(5, 24)),
        china("Nhà Thanh"), khmer("Cao Miên", None, False), *ctx()]),
    S("tu-duc", "Tự Đức", "Pháp chiếm Nam Kỳ", 1870, ["tu-duc"], [
        core("dai-nam", "Đại Nam", "Tự Đức", TEAL, VN(11.5, 24)),
        R("nam-ky", "Nam Kỳ", "Pháp thuộc", PHAP, "rival", VN(5, 11.5)),
        china("Nhà Thanh"), khmer("Cao Miên", "Pháp bảo hộ", False), *ctx()]),
    S("phap", "Pháp thuộc", "Liên bang Đông Dương", 1888, ["can-vuong", "phong-trao-yeu-nuoc"], [
        R("nam-ky", "Nam Kỳ", "Thuộc địa Pháp", PHAP, "rival", VN(5, 11.5)),
        prot("trung-bac-ky", "Trung – Bắc Kỳ", "Pháp bảo hộ", PHAP, VN(11.5, 24)),
        china("Nhà Thanh"), khmer("Cao Miên", "Pháp bảo hộ", False), *ctx()]),
]

# ---- emit Dart ----
def fmt_offsets(rs):
    return "[" + ", ".join(
        "[" + ", ".join(f"Offset({x},{y})" for x, y in r) + "]" for r in rs) + "]"

def esc(s):
    return s.replace("'", r"\'")

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

CONST_RINGS = {name: rings(g) for name, g in CONSTS.items()}
for name, rs in CONST_RINGS.items():
    lines.append(f"const List<List<Offset>> {name} = {fmt_offsets(rs)};")
lines.append("")
lines.append("const List<AtlasSnapshot> kAtlas = <AtlasSnapshot>[")

for snap in SNAPSHOTS:
    lines.append(f"  AtlasSnapshot(id: '{snap['id']}', title: '{esc(snap['title'])}',")
    sub = "null" if snap["sub"] is None else "'{}'".format(esc(snap["sub"]))
    lines.append(f"    subtitle: {sub}, anchorYear: {snap['anchor']}, mapAspect: kAtlasAspect,")
    eras = ", ".join("'{}'".format(e) for e in snap["eras"])
    lines.append(f"    eras: <String>[{eras}],")
    b = snap.get("boundary")
    if b:
        lat, lon0, lon1 = b
        p0 = proj(lon0, lat); p1 = proj(lon1, lat)
        lines.append(f"    boundary: <Offset>[Offset({p0[0]},{p0[1]}), Offset({p1[0]},{p1[1]})],")
        lines.append(f"    boundaryLabel: '{esc(snap['boundary_label'])}',")
    lines.append("    regions: <AtlasRegion>[")
    for r in snap["regs"]:
        rs = CONST_RINGS[r["const"]] if r["const"] else rings(r["geom"])
        rg = r["const"] if r["const"] else fmt_offsets(rs)
        if not rs:
            continue
        lab = "Offset({},{})".format(*centroid_norm(rs)) if r["label"] else "null"
        sub = "null" if r["sub"] is None else "'{}'".format(esc(r["sub"]))
        lines.append(
            "      AtlasRegion(id: '{id}', name: '{n}', subtitle: {s}, "
            "color: 0x{c:08X}, role: AtlasRole.{role}, labelAt: {lab}, rings: {rg}),".format(
                id=r["id"], n=esc(r["name"]), s=sub, c=r["color"],
                role=r["role"], lab=lab, rg=rg))
    lines.append("    ]),")
lines.append("];")

open(DST, "w").write("\n".join(lines) + "\n")
print("wrote", DST)
print("snapshots:", len(SNAPSHOTS), "eras covered:",
      sum(len(s["eras"]) for s in SNAPSHOTS))

# ---- verification preview ----
def render_preview():
    from PIL import Image, ImageDraw
    W = 300; H = int(W / ASPECT)
    def argb(c): return ((c >> 16) & 255, (c >> 8) & 255, c & 255, (c >> 24) & 255)
    def pxp(p): return (p[0] * W, p[1] * H)
    modern = rings(VN_MAIN)
    order = {"neighbour": 0, "protectorate": 1, "core": 2, "rival": 2}
    def draw(snap):
        img = Image.new("RGBA", (W, H), (12, 23, 20, 255)); d = ImageDraw.Draw(img, "RGBA")
        for r in sorted(snap["regs"], key=lambda r: order[r["role"]]):
            rs = CONST_RINGS[r["const"]] if r["const"] else rings(r["geom"])
            col = argb(r["color"])
            al = {"neighbour": 70, "protectorate": 95, "core": 205, "rival": 205}[r["role"]]
            for ring in rs:
                d.polygon([pxp(p) for p in ring], fill=(col[0], col[1], col[2], al),
                          outline=(198, 160, 74, 140))
            if r["role"] == "protectorate":  # hatch hint
                for ring in rs:
                    xs = [pxp(p) for p in ring]
                    d.line(xs, fill=(240, 220, 150, 120), width=1)
        for ring in modern:
            pts = [pxp(p) for p in ring] + [pxp(ring[0])]
            for i in range(len(pts) - 1):
                a, b = pts[i], pts[i + 1]; seg = math.hypot(b[0]-a[0], b[1]-a[1]); n = max(1, int(seg/4))
                for k in range(n):
                    if k % 2 == 0:
                        t0 = k/n; t1 = (k+0.6)/n
                        d.line([(a[0]+(b[0]-a[0])*t0, a[1]+(b[1]-a[1])*t0),
                                (a[0]+(b[0]-a[0])*t1, a[1]+(b[1]-a[1])*t1)], fill=(240,205,120,200), width=1)
        d.text((6, 5), snap["title"], fill=(240, 205, 120, 255))
        d.text((6, 16), snap["sub"] or "", fill=(200, 190, 170, 220))
        return img
    cols = 6
    rows = (len(SNAPSHOTS) + cols - 1) // cols
    gap = 8
    sheet = Image.new("RGBA", (W*cols+gap*(cols+1), (H+gap)*rows+gap), (8, 15, 13, 255))
    for i, snap in enumerate(SNAPSHOTS):
        r, c = divmod(i, cols)
        sheet.paste(draw(snap), (gap+c*(W+gap), gap+r*(H+gap)), draw(snap))
    out = os.path.join(_HERE, "rebuild_preview.png")
    sheet.convert("RGB").save(out); print("preview:", out)

if os.environ.get("PREVIEW") == "1":
    render_preview()
