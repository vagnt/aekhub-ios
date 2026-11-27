#!/usr/bin/env python3
"""Οριζόντια «Header» του App Store (5244×2950 και 3840×1646): κινητά με screenshots + εικονίδιο + τίτλος.

python3 ci/header.py <φάκελος με iphone69-N.png> <φάκελος εξόδου>
Κεφαλαία χωρίς τόνους (κανόνας τόνων).
"""
import os, sys, math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS = os.path.join(ROOT, 'Resources', 'Fonts')
ASSETS = os.path.join(ROOT, 'iOS', 'Assets.xcassets')
GOLD, INK, TEXT2 = (249, 207, 28), (11, 11, 10), (207, 203, 190)

# (όνομα, κίτρινη γραμμή, λευκή γραμμή, υπότιτλος, [screenshots: αριστερά…, δεξιά…], διάταξη)
VARIANTS = [
    ('1-ola', 'ΟΛΗ Η ΑΕΚ', 'ΣΕ ΕΝΑ APP', 'Ειδήσεις · Live σκορ · Βαθμολογίες', [2, 4], 'sides'),
    ('2-live', 'LIVE', 'ΚΑΘΕ ΑΓΩΝΑΣ', 'Σκορ, φάσεις και συνθέσεις τη στιγμή που γίνονται', [3, 2, 4], 'fan'),
    ('3-tmimata', 'ΟΛΑ ΤΑ ΤΜΗΜΑΤΑ', 'ΤΗΣ ΑΕΚ', 'Ποδόσφαιρο · Μπάσκετ · Ερασιτεχνική', [1, 9], 'sides'),
]


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), int(size))


def phone(shot, h):
    """Κινητό (iPhone 17 Pro Max) με το screenshot: σκούρο σώμα, λεπτό περίγραμμα, Dynamic Island."""
    s = Image.open(shot).convert('RGB')
    if os.path.basename(shot) in ('iphone69-3.png', 'iphone69-4.png'):  # κυλισμένες οθόνες: καθαρή μαύρη μπάρα κάτω από την ώρα
        ImageDraw.Draw(s).rectangle([0, 0, s.size[0], int(s.size[1] * 0.058)], fill=INK)
    sw = int(h * s.size[0] / s.size[1]); s = s.resize((sw, h), Image.LANCZOS)
    b = int(h * 0.016)  # πάχος σώματος
    W, H = sw + 2 * b, h + 2 * b
    R = int(W * 0.17)
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, W - 1, H - 1], R, fill=(64, 63, 60, 255))            # πλαίσιο τιτανίου
    d.rounded_rectangle([3, 3, W - 4, H - 4], R - 3, fill=(18, 18, 17, 255))         # μαύρο σώμα
    m = Image.new('L', (sw, h), 0); ImageDraw.Draw(m).rounded_rectangle([0, 0, sw - 1, h - 1], R - b, fill=255)
    im.paste(s, (b, b), m)
    iw, ih = int(sw * 0.3), int(sw * 0.085)  # Dynamic Island
    ImageDraw.Draw(im).rounded_rectangle([(W - iw) // 2, b + int(h * 0.012), (W + iw) // 2, b + int(h * 0.012) + ih], ih // 2, fill=(0, 0, 0, 255))
    return im


def place(bg, ph, cx, cy, angle):
    """Κινητό στραμμένο λίγο, με σκιά, με κέντρο (cx, cy) — μπορεί να βγαίνει έξω από την εικόνα."""
    if angle:
        ph = ph.rotate(angle, resample=Image.BICUBIC, expand=True)
    sh = Image.new('RGBA', ph.size, (0, 0, 0, 0)); sh.putalpha(ph.split()[3].point(lambda a: int(a * 0.75)))
    pad = int(ph.size[0] * 0.15)
    shadow = Image.new('RGBA', (ph.size[0] + 2 * pad, ph.size[1] + 2 * pad), (0, 0, 0, 0))
    shadow.paste(sh, (pad, pad)); shadow = shadow.filter(ImageFilter.GaussianBlur(pad // 2))
    x, y = int(cx - ph.size[0] / 2), int(cy - ph.size[1] / 2)
    bg.paste(shadow, (x - pad + pad // 4, y - pad + pad // 2), shadow)
    bg.paste(ph, (x, y), ph)


def background(W, H):
    bg = Image.new('RGBA', (W, H), INK + (255,))
    try:  # κερκίδα, πολύ σκοτεινή
        hero = Image.open(os.path.join(ASSETS, 'HeroBg.imageset', 'HeroBg.jpg')).convert('RGB')
        k = max(W / hero.size[0], H / hero.size[1]); hero = hero.resize((int(hero.size[0] * k) + 1, int(hero.size[1] * k) + 1))
        hero = hero.crop(((hero.size[0] - W) // 2, (hero.size[1] - H) // 2, (hero.size[0] - W) // 2 + W, (hero.size[1] - H) // 2 + H))
        hero = Image.blend(hero.filter(ImageFilter.GaussianBlur(W // 300)), Image.new('RGB', (W, H), INK), 0.86)
        bg.paste(hero, (0, 0))
    except Exception as e:
        print('χωρίς φόντο:', e)
    # λεπτές διαγώνιες κίτρινες γραμμές
    lay = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(lay)
    step, lw = int(H * 0.06), max(2, int(H * 0.004))
    for x in range(-H, W + H, step):
        d.line([(x, H), (x + H, 0)], fill=GOLD + (16,), width=lw)
    bg.alpha_composite(lay)
    # κίτρινη λάμψη στο κέντρο + σκοτείνιασμα στις άκρες
    glow = Image.new('L', (W, H), 0)
    ImageDraw.Draw(glow).ellipse([W * 0.28, H * 0.1, W * 0.72, H * 0.95], fill=60)
    glow = glow.filter(ImageFilter.GaussianBlur(W // 12))
    bg.paste(Image.new('RGBA', (W, H), GOLD + (255,)), (0, 0), glow)
    vig = Image.new('L', (W, H), 0)
    ImageDraw.Draw(vig).rectangle([0, 0, W, H], fill=150); ImageDraw.Draw(vig).ellipse([-W * 0.1, -H * 0.3, W * 1.1, H * 1.3], fill=0)
    bg.paste(Image.new('RGBA', (W, H), (0, 0, 0, 255)), (0, 0), vig.filter(ImageFilter.GaussianBlur(W // 15)))
    return bg


def text_block(bg, W, H, y1, y2, sub, wide):
    d = ImageDraw.Draw(bg)
    scale = H * (1.0 if not wide else 1.12)
    icon_s = int(scale * 0.13)
    big = font('SofiaSans-Black.ttf', scale * 0.155)
    lim = W * (0.34 if not wide else 0.29)
    while max(d.textlength(y1, font=big), d.textlength(y2, font=big)) > lim:
        big = font('SofiaSans-Black.ttf', big.size - 4)
    sf = font('Manrope-Bold.ttf', scale * 0.042)
    while d.textlength(sub, font=sf) > lim:
        sf = font('Manrope-Bold.ttf', sf.size - 2)
    total = icon_s + scale * 0.05 + big.size * 2 * 0.98 + scale * 0.03 + sf.size
    y = (H - total) / 2
    try:  # εικονίδιο της εφαρμογής με στρογγυλές γωνίες
        ic = Image.open(os.path.join(ASSETS, 'AppIcon.appiconset', 'icon-1024.png')).convert('RGB').resize((icon_s, icon_s), Image.LANCZOS)
        m = Image.new('L', ic.size, 0); ImageDraw.Draw(m).rounded_rectangle([0, 0, icon_s - 1, icon_s - 1], int(icon_s * 0.225), fill=255)
        bg.paste(ic, ((W - icon_s) // 2, int(y)), m)
    except Exception as e:
        print('χωρίς εικονίδιο:', e)
    y += icon_s + scale * 0.05
    for t, col in ((y1, (255, 255, 255)), (y2, GOLD)):
        w = d.textlength(t, font=big); d.text(((W - w) / 2, y), t, font=big, fill=col); y += big.size * 0.98
    y += scale * 0.03
    w = d.textlength(sub, font=sf); d.text(((W - w) / 2, y), sub, font=sf, fill=TEXT2)


def make(src, out, W, H, v):
    name, l1, l2, sub, shots, mode = v
    wide = W / H > 2
    bg = background(W, H)
    ph_h = int(H * (0.98 if not wide else 1.12))
    phones = [phone(os.path.join(src, 'iphone69-%d.png' % n), ph_h) for n in shots]
    e = 0.03 if wide else 0  # στη στενή εικόνα τα κινητά πιο έξω
    if mode == 'sides':
        place(bg, phones[0], W * (0.16 - e), H * 0.60, 7)
        place(bg, phones[1], W * (0.84 + e), H * 0.60, -7)
    else:  # fan: δύο αριστερά (πίσω/μπρος) και ένα δεξιά
        place(bg, phones[0], W * (0.10 - e), H * 0.66, 12)
        place(bg, phones[1], W * (0.205 - e), H * 0.58, 4)
        place(bg, phones[2], W * (0.835 + e), H * 0.60, -7)
    text_block(bg, W, H, l1, l2, sub, wide)
    p = os.path.join(out, 'header-%s-%dx%d.png' % (name, W, H))
    bg.convert('RGB').save(p, optimize=True); print(os.path.basename(p))


if __name__ == '__main__':
    src, out = sys.argv[1], sys.argv[2]; os.makedirs(out, exist_ok=True)
    for v in VARIANTS:
        for W, H in ((5244, 2950), (3840, 1646)):
            make(src, out, W, H, v)
