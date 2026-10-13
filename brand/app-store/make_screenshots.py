"""Compose App Store iPhone screenshots (1206x2622 = 6.3", 1179x2556 = 6.1") — same look as brand/play-store,
but with an iPhone (Dynamic Island) mock-up.

Usage: python3 make_screenshots.py [SRC_DIR]
SRC_DIR holds hong-bang / map / quang-trung / son-tinh / khang-chien (.jpg or .png);
defaults to ../play-store/src. Output: screenshots-vi/, screenshots-en/ next to this file.
"""
import importlib.util, os, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("play", os.path.join(HERE, "../play-store/make_screenshots.py"))
play = importlib.util.module_from_spec(spec); spec.loader.exec_module(play)
CARDS, GOLD, CREAM, rounded_mask, spaced, spaced_width = (
    play.CARDS, play.GOLD, play.CREAM, play.rounded_mask, play.spaced, play.spaced_width)

SIZES = [(1206, 2622), (1179, 2556)]   # App Store accepted: 6.3" and 6.1" iPhone
W, H = SIZES[0]
K = W / 1080                           # scale from the 1080-wide Play Store layout
SS = 2
SCREEN_AR = 1290 / 2796    # iPhone 16/17 Pro Max screen
PLAYFAIR = os.path.join(HERE, "../../packages/ui_kit/fonts/PlayfairDisplay-Variable.ttf")
PLAYFAIR_I = os.path.join(HERE, "../../packages/ui_kit/fonts/PlayfairDisplay-Italic-Variable.ttf")
SANS = next((p for p in ("/System/Library/Fonts/HelveticaNeue.ttc",
                         "/usr/share/fonts/opentype/inter/Inter-Regular.otf") if os.path.exists(p)), None)

def s(v): return round(v * K)

def font(path, size, wght=None):
    f = ImageFont.truetype(path, s(size))
    if wght:
        try: f.set_variation_by_axes([wght])
        except Exception: pass
    return f

def background(tint):
    base = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(base)
    top, bot = (8, 12, 11), (14, 15, 12)
    for y in range(H):
        t = y / H
        d.line([(0, y), (W, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
    glow = Image.new("RGB", (W, H), (0, 0, 0))
    ImageDraw.Draw(glow).ellipse([s(-200), s(800), W + s(200), H + s(500)], fill=tint)
    base = ImageChops.add(base, glow.filter(ImageFilter.GaussianBlur(s(220))))
    gold = Image.new("RGB", (W, H), (0, 0, 0))
    ImageDraw.Draw(gold).ellipse([s(140), s(480), W - s(140), s(1150)], fill=(60, 44, 14))
    base = ImageChops.add(base, gold.filter(ImageFilter.GaussianBlur(s(170))))
    import random
    rnd = random.Random(7); d = ImageDraw.Draw(base, "RGBA")
    for _ in range(110):
        x, y, r = rnd.randrange(W), rnd.randrange(H), rnd.choice([1, 1, 2, 2, 3])
        d.ellipse([x - r, y - r, x + r, y + r], fill=(232, 193, 112, rnd.randrange(30, 110)))
    return base.convert("RGBA")

def cover(shot, w, h):
    """Scale-and-crop to w x h (no distortion)."""
    r = max(w / shot.width, h / shot.height)
    im = shot.convert("RGBA").resize((round(shot.width * r), round(shot.height * r)), Image.LANCZOS)
    l, t = (im.width - w) // 2, (im.height - h) // 2
    return im.crop((l, t, l + w, t + h))

def iphone(shot, sw):
    """iPhone Pro mock-up (titanium frame, Dynamic Island). sw = screen width."""
    sh = round(sw / SCREEN_AR)
    bez = 14 * SS
    rad = round(sw * SS * 0.128)            # screen corner radius ≈ 12.8% of width
    sw, sh = sw * SS, sh * SS
    pw, ph = sw + bez * 2, sh + bez * 2
    body = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
    # side buttons first (behind the frame)
    d = ImageDraw.Draw(body)
    btn = (74, 71, 66, 255)
    d.rounded_rectangle([0, ph * 0.155, 5 * SS, ph * 0.185], 2 * SS, fill=btn)   # action
    d.rounded_rectangle([0, ph * 0.215, 5 * SS, ph * 0.285], 2 * SS, fill=btn)   # vol +
    d.rounded_rectangle([0, ph * 0.305, 5 * SS, ph * 0.375], 2 * SS, fill=btn)   # vol -
    d.rounded_rectangle([pw - 5 * SS, ph * 0.255, pw, ph * 0.355], 2 * SS, fill=btn)  # power
    ins = 5 * SS
    fw, fh = pw - 2 * ins, ph - 2 * ins
    body.paste(Image.new("RGBA", (fw, fh), (118, 113, 104, 255)), (ins, 0 + ins), rounded_mask((fw, fh), rad + bez))
    iw, ih = fw - 4 * SS, fh - 4 * SS
    body.paste(Image.new("RGBA", (iw, ih), (6, 6, 8, 255)), (ins + 2 * SS, ins + 2 * SS), rounded_mask((iw, ih), rad + bez - 2 * SS))
    body.paste(cover(shot, sw, sh), (bez, bez), rounded_mask((sw, sh), rad))
    # Dynamic Island
    d = ImageDraw.Draw(body)
    iw_, ih_ = round(sw * 0.275), round(sw * 0.082)
    x0, y0 = (pw - iw_) // 2, bez + round(sw * 0.027)
    d.rounded_rectangle([x0, y0, x0 + iw_, y0 + ih_], ih_ // 2, fill=(0, 0, 0, 255))
    r = ih_ // 5
    cx, cy = x0 + iw_ - ih_ // 2 - r // 2, y0 + ih_ // 2
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(14, 16, 30, 255))
    return body

def find_src(src, name):
    for ext in (".jpg", ".jpeg", ".png", ".webp"):
        p = os.path.join(src, name + ext)
        if os.path.exists(p): return p
    sys.exit(f"missing source screenshot: {os.path.join(src, name)}.(jpg|png)")

def build(card, lang, src, out):
    eyebrow, lines, sub = card[lang]
    img = background(card["tint"])
    d = ImageDraw.Draw(img)
    f_eye = font(SANS, 27)
    ew = spaced_width(d, eyebrow, f_eye, s(7))
    spaced(d, ((W - ew) / 2, s(130)), eyebrow, f_eye, GOLD + (255,), s(7))
    d.line([(W / 2 - s(40), s(190)), (W / 2 + s(40), s(190))], fill=GOLD + (140,), width=2)
    f_h = font(PLAYFAIR, 84, 600)
    y = s(232)
    for text, gold in lines:
        tw = d.textlength(text, font=f_h)
        d.text(((W - tw) / 2 + 2, y + 3), text, font=f_h, fill=(0, 0, 0, 150))
        d.text(((W - tw) / 2, y), text, font=f_h, fill=(GOLD if gold else CREAM) + (255,))
        y += s(104)
    f_s = font(PLAYFAIR_I, 36, 400)
    tw = d.textlength(sub, font=f_s)
    d.text(((W - tw) / 2, y + s(22)), sub, font=f_s, fill=(214, 204, 178, 235))
    shot = Image.open(find_src(src, card["img"]))
    ph = iphone(shot, s(720 if card["tilt"] else 760))
    if card["tilt"]:
        ph = ph.rotate(card["tilt"], resample=Image.BICUBIC, expand=True)
    ph = ph.resize((ph.width // SS, ph.height // SS), Image.LANCZOS)
    px, py = (W - ph.width) // 2, s(640) if not card["tilt"] else s(600)
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 255), (px, py + s(26)), ph.getchannel("A").point(lambda v: int(v * 0.75)))
    img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(s(34))))
    img.alpha_composite(ph, (px, py))
    img.convert("RGB").save(out, optimize=True)

if __name__ == "__main__":
    src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "../play-store/src")
    global_ns = globals()
    for W_, H_ in SIZES:
        global_ns.update(W=W_, H=H_, K=W_ / 1080)
        for i, c in enumerate(CARDS, 1):
            for lang in ("vi", "en"):
                d_ = os.path.join(HERE, f"screenshots-{lang}", f"{W_}x{H_}")
                os.makedirs(d_, exist_ok=True)
                build(c, lang, src, os.path.join(d_, f"{i:02d}-{c['img']}.png"))
    print("done")
