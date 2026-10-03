"""Compose Play Store phone screenshots (1080x1920): headline + Android phone mock-up."""
import math, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

W, H = 1080, 1920
SS = 2  # supersample for mock-up edges
PLAYFAIR = "../../packages/ui_kit/fonts/PlayfairDisplay-Variable.ttf"
PLAYFAIR_I = "../../packages/ui_kit/fonts/PlayfairDisplay-Italic-Variable.ttf"
SANS = "/System/Library/Fonts/HelveticaNeue.ttc"
GOLD, CREAM = (232, 193, 112), (246, 238, 220)

CARDS = [  # file, tilt, bg tint, eyebrow, headline lines (gold-flag), sub
 dict(img="hong-bang", tilt=-7, tint=(14, 40, 34),
  vi=("KỶ NGUYÊN KHỞI THỦY", [("Từ buổi bình minh", 0), ("dựng nước", 1)], "Hành trình lịch sử Việt Nam, trong tay bạn"),
  en=("THE DAWN OF A NATION", [("From the dawn", 0), ("of a nation", 1)], "The story of Vietnam, in your hands")),
 dict(img="map", tilt=0, tint=(12, 36, 40),
  vi=("BẢN ĐỒ LÃNH THỔ", [("Kéo thanh thời gian,", 0), ("bờ cõi đổi thay", 1)], "Xem thế lực qua từng thời kỳ"),
  en=("TERRITORY MAP", [("Drag the timeline,", 0), ("watch borders change", 1)], "See who held each land, era by era")),
 dict(img="quang-trung", tilt=0, tint=(52, 22, 16),
  vi=("TỪNG THỜI KỲ", [("Mỗi triều đại,", 0), ("một câu chuyện", 1)], "Đọc sử song ngữ Việt – Anh"),
  en=("ERA BY ERA", [("Every dynasty,", 0), ("a story to read", 1)], "Read in Vietnamese or English")),
 dict(img="son-tinh", tilt=0, tint=(18, 40, 26),
  vi=("NHÂN VẬT & THẦN THOẠI", [("Gặp gỡ các vị thần", 0), ("và anh hùng", 1)], "Chân dung vẽ tay mang phong vị sơn mài"),
  en=("FIGURES & LEGENDS", [("Meet the gods", 0), ("and heroes", 1)], "Painterly portraits, lacquer-inspired")),
 dict(img="khang-chien", tilt=0, tint=(56, 30, 14),
  vi=("ĐẾN THỜI HIỆN ĐẠI", [("Từ thuở dựng nước", 0), ("đến hôm nay", 1)], "Dòng chảy lịch sử liền mạch"),
  en=("TO THE MODERN DAY", [("From the first kings", 0), ("to today", 1)], "One unbroken thread of history")),
]

def font(path, size, wght=None):
    f = ImageFont.truetype(path, size)
    if wght:
        try: f.set_variation_by_axes([wght])
        except Exception: pass
    return f

def background(tint):
    base = Image.new("RGB", (W, H))
    px = base.load()
    top, bot = (8, 12, 11), (14, 15, 12)
    for y in range(H):
        t = y / H
        c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))
        for x in range(W): px[x, y] = c
    glow = Image.new("RGB", (W, H), (0, 0, 0))
    d = ImageDraw.Draw(glow)
    d.ellipse([-200, 600, W + 200, 2300], fill=tint)
    glow = glow.filter(ImageFilter.GaussianBlur(220))
    base = ImageChops.add(base, glow)
    gold = Image.new("RGB", (W, H), (0, 0, 0))
    d = ImageDraw.Draw(gold)
    d.ellipse([140, 360, W - 140, 900], fill=(60, 44, 14))
    gold = gold.filter(ImageFilter.GaussianBlur(170))
    base = ImageChops.add(base, gold)
    # gold dust
    rnd = random.Random(7); d = ImageDraw.Draw(base, "RGBA")
    for _ in range(90):
        x, y, r = rnd.randrange(W), rnd.randrange(H), rnd.choice([1, 1, 2, 2, 3])
        d.ellipse([x - r, y - r, x + r, y + r], fill=(232, 193, 112, rnd.randrange(30, 110)))
    return base.convert("RGBA")

def rounded_mask(size, radius):
    m = Image.new("L", (size[0] * 4, size[1] * 4), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0] * 4 - 1, size[1] * 4 - 1], radius * 4, fill=255)
    return m.resize(size, Image.LANCZOS)

def phone(shot, sw):
    """Android phone with the screenshot on its screen. sw = screen width."""
    sh = round(sw * shot.height / shot.width)
    bez, rad = 20 * SS, 74 * SS
    sw, sh = sw * SS, sh * SS
    pw, ph = sw + bez * 2, sh + bez * 2
    body = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
    # titanium rim + black body
    rim = Image.new("RGBA", (pw, ph), (96, 92, 84, 255))
    body.paste(rim, (0, 0), rounded_mask((pw, ph), rad + bez))
    inner = Image.new("RGBA", (pw - 6 * SS, ph - 6 * SS), (6, 6, 8, 255))
    body.paste(inner, (3 * SS, 3 * SS), rounded_mask(inner.size, rad + bez - 3 * SS))
    scr = shot.convert("RGBA").resize((sw, sh), Image.LANCZOS)
    body.paste(scr, (bez, bez), rounded_mask((sw, sh), rad))
    d = ImageDraw.Draw(body)
    cx, cy, r = pw // 2, bez + 38 * SS, 13 * SS  # punch-hole camera
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(4, 4, 6, 255))
    d.ellipse([cx - r + 4 * SS, cy - r + 4 * SS, cx + r - 4 * SS, cy + r - 4 * SS], fill=(20, 24, 44, 255))
    # side buttons
    for y0, y1 in ((ph * 0.20, ph * 0.28), (ph * 0.32, ph * 0.46)):
        d.rounded_rectangle([pw - 4 * SS, y0, pw, y1], 3 * SS, fill=(80, 76, 70, 255))
    return body

def spaced(d, xy, text, f, fill, track):
    x, y = xy
    for ch in text:
        d.text((x, y), ch, font=f, fill=fill)
        x += d.textlength(ch, font=f) + track

def spaced_width(d, text, f, track):
    return sum(d.textlength(c, font=f) + track for c in text) - track

def build(card, lang, out):
    eyebrow, lines, sub = card[lang]
    img = background(card["tint"])
    d = ImageDraw.Draw(img)
    # text block
    f_eye = font(SANS, 27)
    ew = spaced_width(d, eyebrow, f_eye, 7)
    spaced(d, ((W - ew) / 2, 96), eyebrow, f_eye, GOLD + (255,), 7)
    d.line([(W / 2 - 40, 150), (W / 2 + 40, 150)], fill=GOLD + (140,), width=2)
    f_h = font(PLAYFAIR, 84, 600)
    y = 182
    for text, gold in lines:
        tw = d.textlength(text, font=f_h)
        d.text(((W - tw) / 2 + 2, y + 3), text, font=f_h, fill=(0, 0, 0, 150))
        d.text(((W - tw) / 2, y), text, font=f_h, fill=(GOLD if gold else CREAM) + (255,))
        y += 104
    f_s = font(PLAYFAIR_I, 36, 400)
    tw = d.textlength(sub, font=f_s)
    d.text(((W - tw) / 2, y + 22), sub, font=f_s, fill=(214, 204, 178, 235))
    # phone
    shot = Image.open(f"src/{card['img']}.jpg")
    ph = phone(shot, 720)
    if card["tilt"]:
        ph = ph.rotate(card["tilt"], resample=Image.BICUBIC, expand=True)
    ph = ph.resize((ph.width // SS, ph.height // SS), Image.LANCZOS)
    px, py = (W - ph.width) // 2, 560 if not card["tilt"] else 520
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    a = ph.getchannel("A").point(lambda v: int(v * 0.75))
    shadow.paste((0, 0, 0, 255), (px, py + 26), a)
    img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(34)))
    img.alpha_composite(ph, (px, py))
    img.convert("RGB").save(out, optimize=True)

for i, c in enumerate(CARDS, 1):
    for lang, dirn in (("vi", "screenshots-vi"), ("en", "screenshots-en")):
        build(c, lang, f"{dirn}/{i:02d}-{c['img']}.png")
print("done")
