#!/usr/bin/env python3
"""Εικόνες App Store με τίτλο (header) πάνω από το screenshot.

python3 ci/marketing.py <φάκελος screenshots του ci/appstore.sh> <φάκελος εξόδου>
iphone69-N.png → 1320×2868 · ipad13-N.png → 2064×2752 (ίδιο μέγεθος με την πηγή, όπως ζητά η Apple).
Κεφαλαία χωρίς τόνους (κανόνας τόνων).
"""
import os, sys, glob
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS = os.path.join(ROOT, 'Resources', 'Fonts')
ASSETS = os.path.join(ROOT, 'iOS', 'Assets.xcassets')
GOLD, INK, TEXT2 = (249, 207, 28), (11, 11, 10), (207, 203, 190)

# ίδια σειρά με το ci/appstore.sh: (κίτρινη γραμμή, λευκή γραμμή, υπότιτλος)
CAPTIONS = [
    ('ΟΛΗ Η ΑΕΚ', 'ΣΕ ΜΙΑ ΕΦΑΡΜΟΓΗ', 'Ειδήσεις, αγώνες και αποτελέσματα'),
    ('LIVE', 'ΚΑΘΕ ΑΓΩΝΑΣ', 'Σκορ, λεπτό και γκολ τη στιγμή που γίνονται'),
    ('ΚΑΘΕ ΦΑΣΗ', 'ΛΕΠΤΟ ΠΡΟΣ ΛΕΠΤΟ', 'Γκολ, κάρτες και αλλαγές με όλες τις λεπτομέρειες'),
    ('ΟΙ ΣΥΝΘΕΣΕΙΣ', 'ΣΤΟ ΓΗΠΕΔΟ', 'Ενδεκάδες, αλλαγές και βαθμολογίες παικτών'),
    ('ΠΡΙΝ', 'ΤΗ ΣΕΝΤΡΑ', 'Αντίστροφη μέτρηση και κανάλια μετάδοσης'),
    ('ΟΛΟ ΤΟ', 'ΠΡΟΓΡΑΜΜΑ', 'Ποδόσφαιρο, μπάσκετ, βόλεϊ και όλα τα τμήματα'),
    ('ΟΛΕΣ ΟΙ', 'ΒΑΘΜΟΛΟΓΙΕΣ', 'Πάντα ενημερωμένες, με την ΑΕΚ να ξεχωρίζει'),
    ('ΔΙΑΒΑΣΕ', 'ΑΝΕΤΑ', 'Άρθρα με φωτογραφίες, βίντεο και σχόλια'),
    ('ΚΑΙ ΣΤΟ', 'ΜΠΑΣΚΕΤ', 'Κάθε τμήμα της ΑΕΚ με την ίδια φροντίδα'),
]


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def rounded(im, r):
    m = Image.new('L', im.size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, im.size[0] - 1, im.size[1] - 1], r, fill=255)
    out = im.convert('RGBA'); out.putalpha(m)
    return out


def background(W, H):
    bg = Image.new('RGB', (W, H), INK)
    try:  # φωτογραφία κερκίδας, σκοτεινή και θολή, μόνο στο πάνω μέρος
        hero = Image.open(os.path.join(ASSETS, 'HeroBg.imageset', 'HeroBg.jpg')).convert('RGB')
        hh = int(H * 0.42)
        hero = hero.resize((W, int(hero.size[1] * W / hero.size[0]))).crop((0, 0, W, hh)) if hero.size[1] * W / hero.size[0] >= hh \
            else hero.resize((int(hero.size[0] * hh / hero.size[1]), hh)).crop((0, 0, W, hh))
        hero = hero.filter(ImageFilter.GaussianBlur(W // 90))
        hero = Image.blend(hero, Image.new('RGB', hero.size, INK), 0.72)
        fade = Image.linear_gradient('L').resize((W, hh))  # 0 πάνω → 255 κάτω
        bg.paste(hero, (0, 0), fade.point(lambda v: 255 - v))
    except Exception as e:
        print('χωρίς φόντο:', e)
    # κίτρινη λάμψη πίσω από το κινητό
    glow = Image.new('L', (W, H), 0)
    ImageDraw.Draw(glow).ellipse([W * 0.1, H * 0.42, W * 0.9, H * 1.05], fill=70)
    glow = glow.filter(ImageFilter.GaussianBlur(W // 6))
    bg.paste(Image.new('RGB', (W, H), GOLD), (0, 0), glow)
    return bg


def compose(shot, cap, pad):
    W, H = shot.size
    bg = background(W, H)
    d = ImageDraw.Draw(bg)
    y = int(H * (0.045 if not pad else 0.04))
    # λογότυπο
    try:
        logo = Image.open(os.path.join(ASSETS, 'Logo.imageset', 'Logo.png')).convert('RGBA')
        lw = int(W * (0.26 if not pad else 0.17)); logo = logo.resize((lw, int(logo.size[1] * lw / logo.size[0])), Image.LANCZOS)
        bg.paste(logo, ((W - lw) // 2, y), logo); y += logo.size[1] + int(H * 0.022)
    except Exception as e:
        print('χωρίς λογότυπο:', e)
    big = font('SofiaSans-Black.ttf', int(W * (0.118 if not pad else 0.078)))
    sub = font('Manrope-Bold.ttf', int(W * (0.038 if not pad else 0.026)))
    for t, col in ((cap[0], GOLD), (cap[1], (255, 255, 255))):
        w = d.textlength(t, font=big)
        d.text(((W - w) / 2, y), t, font=big, fill=col)
        y += int(big.size * 0.98)
    # κίτρινη γραμμούλα ανάμεσα σε τίτλο και φράση
    bw, bh = int(W * 0.07), max(6, int(W * 0.006))
    y += int(H * 0.024); d.rounded_rectangle([(W - bw) // 2, y, (W + bw) // 2, y + bh], bh // 2, fill=GOLD); y += bh + int(H * 0.012)
    while d.textlength(cap[2], font=sub) > W * 0.86 and sub.size > W * (0.031 if not pad else 0.022):  # χωράει σε μία γραμμή
        sub = font('Manrope-Bold.ttf', sub.size - 2)
    w = d.textlength(cap[2], font=sub)
    if w > W * 0.86:  # σε δύο γραμμές
        words = cap[2].split(); half = len(words) // 2
        lines = [' '.join(words[:half + 1]), ' '.join(words[half + 1:])]
    else:
        lines = [cap[2]]
    for ln in lines:
        w = d.textlength(ln, font=sub); d.text(((W - w) / 2, y), ln, font=sub, fill=TEXT2); y += int(sub.size * 1.35)
    y += int(H * 0.025)
    # το screenshot μικρότερο, με στρογγυλές γωνίες και λεπτό περίγραμμα, «βγαίνει» από κάτω
    sw = int(W * (0.84 if not pad else 0.82)); sh = int(H * sw / W)
    s = shot.convert('RGB').resize((sw, sh), Image.LANCZOS)
    r = int(sw * (0.085 if not pad else 0.035))
    frame = Image.new('RGBA', (sw + 16, sh + 16), (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle([0, 0, sw + 15, sh + 15], r + 8, fill=(58, 57, 53, 255))
    shadow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([(W - sw) // 2 - 8, y + 18, (W + sw) // 2 + 8, y + sh + 40], r, fill=(0, 0, 0, 170))
    shadow = shadow.filter(ImageFilter.GaussianBlur(30))
    bg = Image.alpha_composite(bg.convert('RGBA'), shadow)
    bg.paste(frame, ((W - sw) // 2 - 8, y - 8), frame)
    s = rounded(s, r); bg.paste(s, ((W - sw) // 2, y), s)
    return bg.convert('RGB')


def main(src, out):
    os.makedirs(out, exist_ok=True)
    for pre, pad in (('iphone69', False), ('ipad13', True)):
        for f in sorted(glob.glob(os.path.join(src, pre + '-*.png')), key=lambda p: int(p.rsplit('-', 1)[1].split('.')[0])):
            n = int(f.rsplit('-', 1)[1].split('.')[0])
            if n > len(CAPTIONS): continue
            im = Image.open(f)
            res = compose(im, CAPTIONS[n - 1], pad)
            res.save(os.path.join(out, os.path.basename(f)), optimize=True)
            print(os.path.basename(f), res.size)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
