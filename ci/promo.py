#!/usr/bin/env python3
"""🎬 AEK Hub — βίντεο προώθησης για social (Reels / TikTok / Shorts), 1080×1920, 30fps, 28″.

python3 ci/promo.py <φάκελος screenshots του ci/appstore.sh> <badge.png App Store> <aek.png,real.png> <έξοδος.mp4>
ONLY_T=1.4,9 → μόνο αυτά τα καρέ σε png (για έλεγχο).

v3 (26/11, σχόλια χρήστη στη v2): ΧΩΡΙΣ ζουμ μέσα στην οθόνη (έκοβε την εικόνα) · ΧΩΡΙΣ αρίθμηση (01… μπέρδευε
με το «ΟΙ 11») — η ετικέτα δείχνει το ΜΕΣΟ (iPhone / iPad / Apple Watch / οθόνη κλειδώματος) · γραμματοσειρές
ΙΔΙΕΣ με το site (Sofia Sans Extra Condensed **Italic** για τίτλους, Manrope για κείμενα) · ομαλή μετάβαση
«ΣΕ ΚΑΘΕ ΣΥΣΚΕΥΗ.» → «ΣΕ ΚΑΘΕ ΑΘΛΗΜΑ.» → «ΣΕ ΚΑΘΕ ΣΤΙΓΜΗ.» (μένει το «ΣΕ ΚΑΘΕ», αλλάζει η λέξη) · αθλήματα
πιο αργά (ένα ανά χτύπο, «κύλινδρος») · τέλος: «Η ΑΕΚ ΣΤΟ ΚΕΝΤΡΟ ΤΗΣ ΕΝΗΜΕΡΩΣΗΣ.»
Υπογραφή: κίτρινη «λεπίδα» που σκουπίζει την οθόνη σε κάθε αλλαγή σκηνής.
"""
import os, sys, math, wave, subprocess
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS = os.path.join(ROOT, 'Resources', 'Fonts')
ASSETS = os.path.join(ROOT, 'iOS', 'Assets.xcassets')
W, H, FPS = 1080, 1920, 30
BEAT = 0.5  # 120 BPM
GOLD, INK, WHITE = (249, 207, 28), (10, 10, 9), (255, 255, 255)
TEXT2 = (190, 186, 175)

# χρονοδιάγραμμα (σε χτύπους των 0,5″)
T = dict(lock=0.0, mani=2.0, phone=4.0, lineup=7.5, carousel=9.5, ipad=11.5, count=13.5, watch=15.5,
         devices=17.5, sports=19.5, moment=22.5, end=23.5)
DUR = 28.0
BLADES = [(T['phone'], INK), (T['lineup'], GOLD), (T['carousel'], GOLD), (T['ipad'], GOLD), (T['count'], INK),
          (T['watch'], INK), (T['end'], GOLD)]

_fc = {}
def font(n, s):
    k = (n, int(s))
    if k not in _fc:
        if n == 'DISP':  # τίτλοι του site: Sofia Sans Extra Condensed Black Italic
            f = ImageFont.truetype(os.path.join(ROOT, 'ci', 'fonts', 'SofiaSansExtraCondensed-Italic.ttf'), int(s)); f.set_variation_by_axes([900])
        else:
            f = ImageFont.truetype(os.path.join(FONTS, n), int(s))
        _fc[k] = f
    return _fc[k]
DISP = 'DISP'; XB = 'Manrope-ExtraBold.ttf'; BD = 'Manrope-Bold.ttf'

def clamp(x, a=0.0, b=1.0): return max(a, min(b, x))
def prog(t, a, b): return clamp((t - a) / (b - a)) if b > a else float(t >= a)
def eo(t): return 1 - (1 - clamp(t)) ** 3
def eio(t): t = clamp(t); return 4 * t ** 3 if t < .5 else 1 - (-2 * t + 2) ** 3 / 2
def expo(t): t = clamp(t); return 1 if t >= 1 else 1 - 2 ** (-10 * t)
def back(t, c=1.7): t = clamp(t); return 1 + (c + 1) * (t - 1) ** 3 + c * (t - 1) ** 2
def lerp(a, b, p): return a + (b - a) * p


# ═════════════════════ ΗΧΟΣ ═════════════════════
SR = 44100

def build_audio(path):
    n = int(SR * (DUR + .3)); out = np.zeros(n); rng = np.random.default_rng(11)
    def add(sig, at, g=1.0):
        i = int(at * SR)
        if i >= n or i + len(sig) <= 0: return
        j = min(n, i + len(sig)); out[max(0, i):j] += g * sig[max(0, -i):j - i]
    def TT(L): return np.arange(int(L * SR)) / SR
    k = TT(.5); kick = np.tanh(2.6 * np.sin(2 * np.pi * (48 * k + 120 * (1 - np.exp(-k * 35)) / 35)) * np.exp(-k * 6.5))
    x = TT(.3); snare = (rng.standard_normal(len(x)) * np.exp(-x * 18) * .9 + np.sin(2 * np.pi * 190 * x) * np.exp(-x * 25)) * .8
    x = TT(.05); hat = np.diff(np.concatenate([[0], rng.standard_normal(len(x))])) * np.exp(-x * 90)
    x = TT(1.4); impact = (np.sin(2 * np.pi * 38 * x) * np.exp(-x * 3) + rng.standard_normal(len(x)) * np.exp(-x * 9) * .5)
    def ding(at, g=.22):
        for f, d in ((1318.5, 0), (1760, .09)):
            y = TT(.9); add((np.sin(2 * np.pi * f * y) + .3 * np.sin(4 * np.pi * f * y)) * np.exp(-y * 5) * g, at + d)
    def buzz(at):
        y = TT(.35); add(np.sign(np.sin(2 * np.pi * 150 * y)) * (np.sin(np.pi * y / .35) ** 2) * .10, at)
    def whoosh(at, L=.45, g=.35):
        y = TT(L); w = rng.standard_normal(len(y)); w = np.convolve(w, np.ones(24) / 24, 'same') * np.sin(np.pi * y / L) ** 3
        add(w * g * 3, at - L * .6)
    y = TT(2.2); pad = sum(np.sin(2 * np.pi * f * y + i) for i, f in enumerate((110, 164.8, 220, 261.6))) / 4
    add(pad * np.minimum(1, y / .6) * .25, 0)
    buzz(.25); ding(.3); buzz(1.0); ding(1.05)
    y = TT(1.0); r = rng.standard_normal(len(y)) * y ** 3; add(np.convolve(r, np.ones(6) / 6, 'same') * .5, 1.0)
    add(impact, 2.0, .9)
    notes = [55.0, 43.65, 65.41, 49.0]
    t = 2.0
    while t < T['end'] - 1e-6:
        b = int(round((t - 2.0) / BEAT))
        quiet = T['moment'] <= t  # λίγο πριν το τέλος: μόνο ρολό
        if not quiet:
            add(kick, t, 1.0)
            if b % 2 == 1: add(snare, t, .55)
            for q in (.25, .5, .75): add(hat, t + q * BEAT, .32 if q == .5 else .14)
        f = notes[(b // 8) % 4]
        for h in (0, .5):
            y = TT(BEAT / 2); s = np.tanh(2 * (np.sin(2 * np.pi * f * y) + .5 * np.sign(np.sin(2 * np.pi * f * y)))) * np.minimum(1, y / .004) * np.exp(-y / .2)
            add(s * (.24 if not quiet else .12), t + h * BEAT)
        t += BEAT
    for i in range(8): add(snare, T['moment'] + i * .125, .25 + .06 * i)
    for a, _ in BLADES: whoosh(a)
    for i in range(6): add(hat, T['sports'] + i * BEAT, .5)  # «κλικ» κυλίνδρου αθλημάτων
    add(impact, T['end'], 1.0); add(kick, T['end'], 1.0); add(impact, T['end'] + .55, .45)
    y = TT(4.6); chord = sum(np.sin(2 * np.pi * f * y) for f in (220, 277.2, 329.6, 440, 554.4)) / 5
    add(chord * np.minimum(1, y / .05) * np.exp(-y / 2.4) * .35, T['end'])
    ding(T['end'] + 1.1, .18)
    out = np.tanh(out / (np.max(np.abs(out)) + 1e-9) * 1.4) * .92
    out[-int(.6 * SR):] *= np.linspace(1, 0, int(.6 * SR))
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes((out * 32767).astype(np.int16).tobytes())


# ═════════════════════ ΕΡΓΑΛΕΙΑ ═════════════════════

def rounded_mask(w, h, r):
    m = Image.new('L', (int(w), int(h)), 0); ImageDraw.Draw(m).rounded_rectangle([0, 0, int(w) - 1, int(h) - 1], int(r), fill=255); return m

def text_layer(s, f, fill, track=0):
    d0 = ImageDraw.Draw(Image.new('L', (1, 1)))
    w = int(sum(d0.textlength(c, font=f) for c in s) + track * max(0, len(s) - 1)) + int(f.size * .4) + 8
    h = int(f.size * 1.4)
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0)); d = ImageDraw.Draw(im); x = 4
    for c in s:
        d.text((x, 4), c, font=f, fill=fill); x += d0.textlength(c, font=f) + track
    bb = im.getbbox(); return im.crop(bb) if bb else im

_tl = {}
def TL(s, fn, size, fill, track=0):
    k = (s, fn, size, fill, track)
    if k not in _tl: _tl[k] = text_layer(s, font(fn, size), fill, track)
    return _tl[k]

def put(fr, im, x, y, anchor='mm', alpha=1.0):
    if alpha <= 0 or im is None: return
    if alpha < 1:
        im = im.copy(); im.putalpha(im.split()[3].point(lambda v: int(v * alpha)))
    w, h = im.size
    ox = {'l': 0, 'm': w / 2, 'r': w}[anchor[0]]; oy = {'t': 0, 'm': h / 2, 'b': h}[anchor[1]]
    fr.paste(im, (int(x - ox), int(y - oy)), im)

def reveal(fr, im, x, y, p, out=0.0):
    """Η γραμμή ανεβαίνει μέσα από μάσκα· με out>0 φεύγει προς τα πάνω."""
    if p <= 0 or out >= 1: return
    w, h = im.size
    off = int(h * 1.05 * (1 - eo(p))) - int(h * 1.05 * eio(out))
    box = Image.new('RGBA', (w, h), (0, 0, 0, 0)); box.paste(im, (0, off), im)
    put(fr, box, x, y, 'lt')

def find_coeffs(dst, src):
    A, B = [], []
    for (x, y), (X, Y) in zip(dst, src):
        A.append([x, y, 1, 0, 0, 0, -X * x, -X * y]); A.append([0, 0, 0, x, y, 1, -Y * x, -Y * y]); B += [X, Y]
    return np.linalg.solve(np.array(A, float), np.array(B, float)).tolist()


class Device:
    """iPhone / iPad με οθόνη + γυαλάδα, σχεδιασμένο σε 3D (περιστροφή Χ/Υ/Ζ, προοπτική)."""
    def __init__(self, h, aspect, bezel, radius, island):
        self.sh = h; self.sw = int(h * aspect); b = int(h * bezel); self.b = b
        self.W, self.H = self.sw + 2 * b, h + 2 * b; R = int(self.W * radius)
        f = Image.new('RGBA', (self.W, self.H), (0, 0, 0, 0)); d = ImageDraw.Draw(f)
        d.rounded_rectangle([0, 0, self.W - 1, self.H - 1], R, fill=(96, 94, 90, 255))
        d.rounded_rectangle([4, 4, self.W - 5, self.H - 5], R - 4, fill=(20, 20, 19, 255))
        self.mask = rounded_mask(self.sw, h, max(8, R - b))
        hole = Image.new('L', (self.W, self.H), 255); hole.paste(0, (b, b), self.mask)
        f.putalpha(ImageChops.multiply(f.split()[3], hole))
        if island:
            iw, ih = int(self.sw * .3), int(self.sw * .085)
            ImageDraw.Draw(f).rounded_rectangle([(self.W - iw) // 2, b + int(h * .012), (self.W + iw) // 2, b + int(h * .012) + ih], ih // 2, fill=(0, 0, 0, 255))
        self.frame = f
        g = Image.new('L', (self.W, self.H), 0); ImageDraw.Draw(g).polygon([(0, 0), (self.W * .55, 0), (0, self.H * .42)], fill=20)
        self.gloss = g.filter(ImageFilter.GaussianBlur(30))
        self.cache = {}

    def flat(self, screen, key=None):
        if key is not None and key in self.cache: return self.cache[key]
        im = Image.new('RGBA', (self.W, self.H), (0, 0, 0, 0))
        im.paste(screen.resize((self.sw, self.sh), Image.BILINEAR), (self.b, self.b), self.mask)
        im.alpha_composite(self.frame)
        im.paste((255, 255, 255), (0, 0), ImageChops.multiply(self.gloss, im.split()[3]))
        if key is not None: self.cache[key] = im
        return im

    def draw(self, fr, screen, cx, cy, scale=1.0, ry=0.0, rx=0.0, rz=0.0, shadow=.55, key=None):
        im = self.flat(screen, key)
        w, h = self.W * scale, self.H * scale; f = 2600; pts = []
        for (x, y) in ((-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)):
            c, s = math.cos(rz), math.sin(rz); x, y = x * c - y * s, x * s + y * c
            x1, z1 = x * math.cos(ry), x * math.sin(ry)
            y2, z2 = y * math.cos(rx) - z1 * math.sin(rx), y * math.sin(rx) + z1 * math.cos(rx)
            k = f / (f + z2); pts.append((cx + x1 * k, cy + y2 * k))
        xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
        x0, y0 = int(max(-300, min(xs) - 4)), int(max(-300, min(ys) - 4)); x1_, y1_ = int(min(W + 300, max(xs) + 4)), int(min(H + 300, max(ys) + 4))
        bw, bh = x1_ - x0, y1_ - y0
        if bw <= 2 or bh <= 2: return
        warped = im.transform((bw, bh), Image.PERSPECTIVE, find_coeffs([(p[0] - x0, p[1] - y0) for p in pts], [(0, 0), (self.W, 0), (self.W, self.H), (0, self.H)]), Image.BICUBIC)
        if shadow:  # σκιά σε καμβά με περιθώριο (αλλιώς το θόλωμα «κόβεται» σε ορθογώνιο)
            pd = int(max(bw, bh) * .12)
            can = Image.new('L', (bw + 2 * pd, bh + 2 * pd), 0); can.paste(warped.split()[3], (pd, pd))
            a = can.resize((max(1, can.size[0] // 6), max(1, can.size[1] // 6))).filter(ImageFilter.GaussianBlur(10)).resize(can.size)
            fr.paste((0, 0, 0), (x0 - pd + int(30 * scale), y0 - pd + int(60 * scale)), a.point(lambda v: int(v * shadow)))
        fr.paste(warped, (x0, y0), warped)


def label(fr, s, x, y, col=GOLD, alpha=1.0):
    """Ετικέτα του ΜΕΣΟΥ: κουκκίδα + κείμενο (π.χ. ● ΣΤΟ iPHONE)."""
    if alpha <= 0: return
    d = ImageDraw.Draw(fr); a = alpha
    c = tuple(int(lerp(INK[i] if col != INK else GOLD[i], col[i], a)) for i in range(3))
    d.ellipse([x, y + 6, x + 18, y + 24], fill=c)
    put(fr, TL(s, XB, 30, col + (255,), 5), x + 32, y + 15, 'lm', alpha)


def blade(fr, t):
    """Υπογραφή: λοξή «λεπίδα» που σαρώνει την οθόνη στις αλλαγές σκηνής."""
    for c, col in BLADES:
        if c - .2 <= t < c + .2:
            p = eio((t - c + .2) / .4); bw = W * 1.3; x = lerp(-bw - 500, W + 500, p)
            d = ImageDraw.Draw(fr); sk = 520
            d.polygon([(x, H), (x + sk, 0), (x + sk + bw, 0), (x + bw, H)], fill=col)


# ═════════════════════ ΣΚΗΝΕΣ ═════════════════════

class Film:
    def __init__(self, src, badge, logos):
        L = lambda f: Image.open(os.path.join(src, f)).convert('RGB')
        self.s = {k: L(f) for k, f in dict(home='iphone69-1.png', score='iphone69-2.png', timeline='iphone69-3.png', lineup='iphone69-4.png',
                                            pre='iphone69-5.png', matches='iphone69-6.png', table='iphone69-7.png', post='iphone69-8.png',
                                            basket='iphone69-9.png', watch='watch-2.png', watch1='watch-1.png',
                                            ipad='ipad13-2.png', ipad_home='ipad13-1.png').items()}
        self.icon = Image.open(os.path.join(ASSETS, 'AppIcon.appiconset', 'icon-1024.png')).convert('RGB')
        self.badge = Image.open(badge).convert('RGBA')
        self.logos = [Image.open(p).convert('RGBA') for p in logos]
        self.eagle = Image.open(os.path.join(ASSETS, 'Eagle.imageset', 'Eagle.png')).convert('RGBA')
        self.P = Device(1300, 1320 / 2868, .017, .17, True)
        self.Pad = Device(1000, 2064 / 2752, .03, .06, False)
        hero = Image.open(os.path.join(ASSETS, 'HeroBg.imageset', 'HeroBg.jpg')).convert('RGB')
        k = (H * 1.1) / hero.size[1]; hero = hero.resize((int(hero.size[0] * k), int(H * 1.1)))
        hero = hero.crop(((hero.size[0] - int(W * 1.1)) // 2, 0, (hero.size[0] - int(W * 1.1)) // 2 + int(W * 1.1), int(H * 1.1)))
        self.lock = Image.blend(hero.filter(ImageFilter.GaussianBlur(26)), Image.new('RGB', hero.size, INK), .45)
        self.frost = Image.blend(hero.filter(ImageFilter.GaussianBlur(60)), Image.new('RGB', hero.size, (235, 235, 235)), .30)
        rng = np.random.default_rng(1)
        self.noise = (rng.standard_normal((H + 64, W + 64)) * 5).astype(np.float32)
        yy, xx = np.mgrid[0:H, 0:W]; d = np.sqrt(((xx - W / 2) / (W * .75)) ** 2 + ((yy - H / 2) / (H * .7)) ** 2)
        self.vig = np.clip(1.08 - .45 * d ** 2, .55, 1)[..., None].astype(np.float32)
        self.ic = {}

    def app_icon(self, s):
        s = int(s)
        if s not in self.ic:
            im = self.icon.resize((s, s), Image.LANCZOS).convert('RGBA'); im.putalpha(rounded_mask(s, s, int(s * .225))); self.ic[s] = im
        return self.ic[s]

    def logo(self, i, h):
        im = self.logos[i]; return im.resize((int(im.size[0] * h / im.size[1]), h), Image.LANCZOS)

    def title(self, fr, t, t0, l1, l2, c1=WHITE, c2=GOLD, size=128, y=350, t_out=None):
        o = 0 if t_out is None else prog(t, t_out, t_out + .3)
        a = TL(l1, DISP, size, c1 + (255,)); b = TL(l2, DISP, size, c2 + (255,))
        reveal(fr, a, 72, y, prog(t, t0, t0 + .3), o)
        reveal(fr, b, 72, y + int(size * 1.0), prog(t, t0 + .1, t0 + .4), o)

    def watch_img(self, s, ww):
        wh = int(ww * s.size[1] / s.size[0])
        case = Image.new('RGBA', (ww + 80, wh + 80), (0, 0, 0, 0)); cd = ImageDraw.Draw(case)
        cd.rounded_rectangle([0, 0, ww + 79, wh + 79], int(ww * .27), fill=(96, 94, 90, 255))
        cd.rounded_rectangle([7, 7, ww + 72, wh + 72], int(ww * .25), fill=(6, 6, 6, 255))
        case.paste(s.resize((ww, wh)), (40, 40), rounded_mask(ww, wh, int(ww * .2)))
        cd.rounded_rectangle([ww + 74, wh * .32, ww + 86, wh * .52], 5, fill=(120, 118, 112, 255))
        band = Image.new('RGBA', (int(ww * .72), int(wh * 1.75)), (0, 0, 0, 0)); bd = ImageDraw.Draw(band)
        bd.rounded_rectangle([0, 0, band.size[0] - 1, band.size[1] - 1], int(ww * .1), fill=(36, 35, 33, 255))
        for yy in range(20, band.size[1], max(12, ww // 15)): bd.line([(16, yy), (band.size[0] - 16, yy)], fill=(46, 45, 42, 255), width=max(2, ww // 150))
        out = Image.new('RGBA', (case.size[0], band.size[1]), (0, 0, 0, 0))
        out.paste(band, ((case.size[0] - band.size[0]) // 2, 0), band)
        out.paste(case, (0, (band.size[1] - case.size[1]) // 2), case)
        return out

    # ── κλειδωμένη οθόνη: «ΓΚΟΛ ΤΗΣ ΑΕΚ» + Live Activity ──
    def lock_screen(self, t):
        cx = (self.lock.size[0] - W) // 2; cy = (self.lock.size[1] - H) // 2
        fr = self.lock.crop((cx, cy, cx + W, cy + H)).copy()
        put(fr, TL('Τετάρτη 4 Νοεμβρίου', BD, 42, (255, 255, 255, 220)), W / 2, 330, 'mm')
        put(fr, TL('21:47', XB, 250, (255, 255, 255, 245)), W / 2, 470, 'mm')
        def notif(y, ttl, body, p, sh):
            if p <= 0: return
            cw, ch = 960, 210; yy = lerp(-260, y, back(p, 1.4)); x0 = (W - cw) // 2 + int(sh)
            card = self.frost.crop((x0 + cx, int(yy) + cy, x0 + cx + cw, int(yy) + cy + ch)) if yy > -cy else Image.new('RGB', (cw, ch), (90, 90, 90))
            card = card.convert('RGBA'); card.putalpha(rounded_mask(cw, ch, 48)); fr.paste(card, (x0, int(yy)), card)
            put(fr, self.app_icon(92), x0 + 34, yy + ch / 2, 'lm')
            put(fr, TL('AEK HUB', XB, 27, (60, 60, 60, 255), 3), x0 + 150, yy + 40, 'lt')
            put(fr, TL('τώρα', BD, 27, (80, 80, 80, 255)), x0 + cw - 36, yy + 40, 'rt')
            put(fr, TL(ttl, XB, 40, (12, 12, 12, 255)), x0 + 150, yy + 84, 'lt')
            put(fr, TL(body, BD, 32, (40, 40, 40, 255)), x0 + 150, yy + 140, 'lt')
        shake = lambda a: (math.sin(t * 90) * 10 * clamp(1 - (t - a) / .3)) if t > a else 0
        push = eo(prog(t, 1.0, 1.25)) * 236
        notif(720 + push, 'ΓΚΟΛ ΤΗΣ ΑΕΚ!  1–0', "Κοιτά 12' · ΑΕΚ – Ρεάλ Μαδρίτης", prog(t, .25, .6), shake(.25))
        notif(720, 'Live: ΑΕΚ 1–0 Ρεάλ', 'Το σκορ ζωντανά στην οθόνη κλειδώματος', prog(t, 1.0, 1.35), shake(1.0))
        p = eo(prog(t, .55, 1.0))
        if p > 0:
            cw, ch = 960, 300; x0 = (W - cw) // 2; y0 = int(lerp(1900, 1250, p))
            card = Image.new('RGBA', (cw, ch), (16, 16, 15, 235)); card.putalpha(rounded_mask(cw, ch, 54).point(lambda v: int(v * .93)))
            fr.paste(card, (x0, y0), card)
            put(fr, self.logo(0, 120), x0 + 120, y0 + 130); put(fr, self.logo(1, 120), x0 + cw - 120, y0 + 130)
            put(fr, TL('1 – 0', DISP, 160, GOLD + (255,)), W / 2, y0 + 120)
            mins = 12 + int(max(0, t - .6) * 2)
            put(fr, TL(f"{mins}'", XB, 34, (255, 255, 255, 255)), W / 2, y0 + 210)
            bw = cw - 160; d = ImageDraw.Draw(fr)
            d.rounded_rectangle([x0 + 80, y0 + 248, x0 + 80 + bw, y0 + 258], 5, fill=(60, 60, 58))
            d.rounded_rectangle([x0 + 80, y0 + 248, x0 + 80 + int(bw * mins / 90), y0 + 258], 5, fill=GOLD)
            if int(t * 4) % 2 == 0: d.ellipse([x0 + 40, y0 + 36, x0 + 58, y0 + 54], fill=(255, 75, 62))
            put(fr, TL('LIVE', XB, 26, (255, 75, 62, 255), 4), x0 + 68, y0 + 45, 'lm')
        label(fr, 'ΣΤΗΝ ΟΘΟΝΗ ΚΛΕΙΔΩΜΑΤΟΣ', 72, 1600, GOLD, eo(prog(t, 1.2, 1.5)))
        if t > 1.75: fr.paste(GOLD, (0, int(H * (1 - eio(prog(t, 1.75, 2.0)))), W, H))
        return fr

    # ── κίτρινο μανιφέστο ──
    def manifesto(self, t):
        fr = Image.new('RGB', (W, H), GOLD)
        label(fr, 'AEK HUB', 72, 300, INK)
        y = 540
        for s, a in (('ΚΑΘΕ ΓΚΟΛ.', 2.0), ('ΚΑΘΕ ΦΑΣΗ.', 2.5), ('ΚΑΘΕ ΑΓΩΝΑΣ.', 3.0)):
            reveal(fr, TL(s, DISP, 190, INK + (255,)), 72, y, prog(t, a, a + .28)); y += 200
        if t >= 3.5:
            im = TL('LIVE.', DISP, 360, INK + (255,)); p = expo(prog(t, 3.5, 3.7)); sc = lerp(1.3, 1, p)
            put(fr, im.resize((int(im.size[0] * sc), int(im.size[1] * sc))), 72, 1180 + im.size[1] / 2, 'lm')
        return fr

    # ── iPhone 3D: σκορ → πορεία (ΧΩΡΙΣ ζουμ στην οθόνη) ──
    def phone(self, t):
        lt = t - T['phone']; L = T['lineup'] - T['phone']
        fr = Image.new('RGB', (W, H), INK)
        label(fr, 'ΣΤΟ iPHONE', 72, 300)
        self.title(fr, t, T['phone'] + .05, 'ΤΟ ΜΑΤΣ', 'ΣΤΗΝ ΤΣΕΠΗ ΣΟΥ.')
        if lt < 1.75: scr, key = self.s['score'], 'score'
        else:
            # η πορεία «κυλάει»: η κεφαλίδα μένει, το περιεχόμενο ανεβαίνει (σαν αληθινό scroll, χωρίς ζουμ)
            s = self.s['timeline']; top = int(s.size[1] * .12); dy = int(700 * eio(prog(lt, 1.95, 3.3)))
            scr = Image.new('RGB', s.size, (11, 11, 10)); scr.paste(s.crop((0, top + dy, s.size[0], s.size[1])), (0, top)); scr.paste(s.crop((0, 0, s.size[0], top)), (0, 0))
            key = None
        pin = eo(prog(lt, 0, .7)); pout = eio(prog(lt, L - .25, L))
        ry = lerp(.75, -.30, pin) + .10 * math.sin(lt * 1.3)
        self.P.draw(fr, scr, W / 2 + 70, lerp(2300, 1290, pin) + pout * 60, .84, ry=ry, rx=lerp(.35, .12, pin), rz=lerp(-.15, -.04, pin), key=key)
        return fr

    # ── συνθέσεις: όλη η οθόνη μέσα στο κινητό (χωρίς κόψιμο) ──
    def lineup(self, t):
        lt = t - T['lineup']; L = T['carousel'] - T['lineup']
        fr = Image.new('RGB', (W, H), INK)
        label(fr, 'ΣΥΝΘΕΣΕΙΣ', 72, 300)
        self.title(fr, t, T['lineup'] + .05, 'ΟΙ ΕΝΔΕΚΑΔΕΣ.', 'ΣΤΟ ΓΗΠΕΔΟ.')
        pin = eo(prog(lt, 0, .6))
        self.P.draw(fr, self.s['lineup'], lerp(W + 500, W / 2 - 40, pin), 1300, .84, ry=lerp(-.8, .28, pin) + .06 * math.sin(lt * 1.4), rx=.10, rz=.03, key='lineup')
        return fr

    # ── carousel οθονών iPhone ──
    def carousel(self, t):
        lt = t - T['carousel']
        fr = Image.new('RGB', (W, H), INK)
        label(fr, 'ΣΤΟ iPHONE', 72, 300)
        self.title(fr, t, T['carousel'] + .05, 'ΟΛΗ Η ΑΕΚ.', 'ΣΕ ΕΝΑ APP.')
        keys = ['matches', 'table', 'basket', 'post', 'home']
        step = 700; off = step * sum(eio(prog(lt, a, a + .35)) for a in (.3, .8, 1.3))
        for i, k in enumerate(keys):
            x = W / 2 + i * step - off
            if -500 < x < W + 500:
                dist = (x - W / 2) / step
                self.P.draw(fr, self.s[k], x, 1310 + abs(dist) * 50, .84 - abs(dist) * .12, ry=-dist * .45, key=k)
        return fr

    # ── iPad ──
    def ipad(self, t):
        lt = t - T['ipad']
        fr = Image.new('RGB', (W, H), INK)
        label(fr, 'ΣΤΟ iPAD', 72, 300)
        self.title(fr, t, T['ipad'] + .05, 'ΚΑΙ ΣΕ ΜΕΓΑΛΗ', 'ΟΘΟΝΗ.')
        pin = eo(prog(lt, 0, .7))
        self.Pad.draw(fr, self.s['ipad'], W / 2 + 40, lerp(2400, 1250, pin), .98, ry=lerp(.6, -.22, pin) + .05 * math.sin(lt * 1.2), rx=lerp(.3, .10, pin), rz=-.03, key='ipad')
        return fr

    # ── αντίστροφη μέτρηση (κίτρινο) ──
    def countdown(self, t):
        lt = t - T['count']
        fr = Image.new('RGB', (W, H), GOLD)
        label(fr, 'ΠΡΙΝ ΤΗ ΣΕΝΤΡΑ', 72, 300, INK)
        self.title(fr, t, T['count'] + .05, 'ΜΕΤΡΑΜΕ', 'ΑΝΤΙΣΤΡΟΦΑ.', INK, INK, 150)
        sec = 13 - int(lt / BEAT)
        vals = [('06', 'ΜΕΡΕΣ'), ('05', 'ΩΡΕΣ'), ('45', 'ΛΕΠΤΑ'), (f'{sec:02d}', 'ΔΕΥΤ.')]
        bw, gap = 214, 22; x0 = (W - (4 * bw + 3 * gap)) / 2; y0 = 900; d = ImageDraw.Draw(fr)
        for i, (v, l) in enumerate(vals):
            p = back(prog(t, T['count'] + .25 + i * .08, T['count'] + .6 + i * .08))
            if p <= 0: continue
            x = x0 + i * (bw + gap); yy = y0 + (1 - p) * 120
            d.rounded_rectangle([x, yy, x + bw, yy + 260], 34, fill=INK)
            tick = i == 3 and (lt % BEAT) < .12
            put(fr, TL(v, DISP, 160, (WHITE if tick else GOLD) + (255,)), x + bw / 2, yy + 115)
            put(fr, TL(l, XB, 26, TEXT2 + (255,), 3), x + bw / 2, yy + 215)
        pa = eo(prog(t, T['count'] + .7, T['count'] + 1.0))
        put(fr, TL('ΑΕΚ – ΑΣΤΕΡΑΣ AKTOR · ΚΥΠΕΛΛΟ', XB, 34, INK + (255,), 2), W / 2, 1240, 'mm', pa)
        put(fr, TL('και πού θα το δεις, με ένα πάτημα', BD, 36, (60, 50, 10, 255)), W / 2, 1300, 'mm', pa)
        return fr

    # ── Apple Watch → «ΣΕ ΚΑΘΕ ΣΥΣΚΕΥΗ.» → «ΣΕ ΚΑΘΕ ΑΘΛΗΜΑ.» → «ΣΕ ΚΑΘΕ ΣΤΙΓΜΗ.» (μία συνεχής σκηνή) ──
    def every(self, t):
        fr = Image.new('RGB', (W, H), INK)
        # ετικέτα μέσου: Apple Watch → (σβήνει)
        lab_a = 1 - prog(t, T['devices'] - .1, T['devices'] + .2)
        label(fr, 'ΣΤΟ APPLE WATCH', 72, 300, GOLD, lab_a)
        label(fr, 'ΠΑΝΤΟΥ', 72, 300, GOLD, eo(prog(t, T['devices'] + .2, T['devices'] + .5)))
        # τίτλος: πρώτα «ΚΑΙ ΣΤΟΝ / ΚΑΡΠΟ ΣΟΥ.» και μετά «ΣΕ ΚΑΘΕ» + λέξη που αλλάζει
        if t < T['devices'] + .3:
            self.title(fr, t, T['watch'] + .05, 'ΚΑΙ ΣΤΟΝ', 'ΚΑΡΠΟ ΣΟΥ.', t_out=T['devices'] - .05)
        if t >= T['devices'] + .1:
            reveal(fr, TL('ΣΕ ΚΑΘΕ', DISP, 150, WHITE + (255,)), 72, 350, prog(t, T['devices'] + .1, T['devices'] + .4))
            for w_, a, b in (('ΣΥΣΚΕΥΗ.', T['devices'] + .2, T['sports'] - .15), ('ΑΘΛΗΜΑ.', T['sports'], T['moment'] - .15), ('ΣΤΙΓΜΗ.', T['moment'], 99)):
                if a - .01 <= t < b + .32:
                    reveal(fr, TL(w_, DISP, 150, GOLD + (255,)), 72, 500, prog(t, a, a + .3), prog(t, b, b + .3) if b < 99 else 0)
        # συσκευές: το ρολόι μένει στη θέση του, έρχονται iPad + iPhone, μετά φεύγουν όλα για τα αθλήματα
        pin = eo(prog(t, T['devices'], T['devices'] + .7)); pgo = eio(prog(t, T['sports'] - .2, T['sports'] + .3))
        if t < T['sports'] + .35:
            wp = back(prog(t, T['watch'] + .05, T['watch'] + .55)) if t < T['devices'] else 1
            ws = self.s['watch'] if t < T['watch'] + 1.0 else self.s['watch1']
            wscale = lerp(1.0, .52, pin)
            if wp > 0:
                wim = self.watch_img(ws, int(600 * wscale * lerp(.6, 1, wp)))
                wx = lerp(W / 2, W * .80, pin); wy = lerp(1300 + (1 - wp) * 300, 1290, pin) + pgo * 1300
                put(fr, wim, wx, wy)
            if pin > 0:
                self.Pad.draw(fr, self.s['ipad_home'], lerp(-600, W * .30, pin), 1140 + pgo * 1300, .62, ry=.22, rx=.06, shadow=.5, key='ipad_home')
                self.P.draw(fr, self.s['home'], W * .56, lerp(2500, 1250, pin) + pgo * 1300, .60, ry=-.12, rx=.06, key='home')
                put(fr, wim, wx, wy)  # το ρολόι μπροστά
        # αθλήματα: «κύλινδρος», ένα ανά χτύπο
        if T['sports'] <= t < T['moment'] + .4:
            words = ['ΠΟΔΟΣΦΑΙΡΟ', 'ΜΠΑΣΚΕΤ', 'ΒΟΛΕΪ', 'ΧΑΝΤΜΠΟΛ', 'FUTSAL', 'ΠΟΛΟ']
            lt = t - T['sports']; i = min(5, int(lt / BEAT)); ph = eio(prog(lt - i * BEAT, 0, .22))
            fade = 1 - prog(t, T['moment'] - .1, T['moment'] + .3)
            yc = 1150
            win = Image.new('RGBA', (W, 420), (0, 0, 0, 0))
            for j, off in ((i - 1, -1), (i, 0)):
                if j < 0: continue
                im = TL(words[j], DISP, 260, GOLD + (255,))
                if im.size[0] > W * .86: im = im.resize((int(W * .86), int(im.size[1] * W * .86 / im.size[0])), Image.LANCZOS)
                y = 210 + (off + (1 - ph)) * 330 if off == 0 else 210 - ph * 330
                if j == i - 1 and ph >= 1: continue
                put(win, im, W / 2, y)
            put(fr, win, 0, yc - 210, 'lt', fade)
            d = ImageDraw.Draw(fr)  # λεπτές γραμμές-οδηγοί του κυλίνδρου
            for yy in (yc - 190, yc + 190): d.line([(160, yy), (W - 160, yy)], fill=tuple(int(c * .35 * fade) for c in GOLD), width=3)
        # «ΣΕ ΚΑΘΕ ΣΤΙΓΜΗ.»: ρολόι λεπτών που τρέχει
        if t >= T['moment']:
            p = eo(prog(t, T['moment'] + .1, T['moment'] + .4))
            mins = 88 + int((t - T['moment']) * 4)
            put(fr, TL(f"{min(mins, 90)}'", DISP, 300, WHITE + (255,)), W / 2, 1150, 'mm', p)
        return fr

    # ── τέλος ──
    def end(self, t):
        lt = t - T['end']
        fr = Image.new('RGB', (W, H), INK)
        p = back(prog(lt, .1, .6), 1.6)
        eg = self.eagle.resize((900, int(900 * self.eagle.size[1] / self.eagle.size[0])), Image.LANCZOS)
        eg.putalpha(eg.split()[3].point(lambda v: int(v * .07 * clamp(p))))
        put(fr, eg, W / 2, 760 - lt * 6)
        g = Image.new('L', (W // 4, H // 4), 0)
        ImageDraw.Draw(g).ellipse([W / 8 - 110, 640 / 4 - 110, W / 8 + 110, 640 / 4 + 110], fill=int(110 * clamp(p)))
        fr.paste(GOLD, (0, 0), g.filter(ImageFilter.GaussianBlur(28)).resize((W, H)))
        s = int(300 * max(.01, p))
        if s > 4: put(fr, self.app_icon(s), W / 2, 640)
        pa = expo(prog(lt, .5, .75))
        if pa > 0: put(fr, TL('AEK HUB', DISP, 210, WHITE + (255,), int(lerp(40, 4, pa))), W / 2, 935, 'mm', pa)
        l1 = TL('Η ΑΕΚ ΣΤΟ ΚΕΝΤΡΟ', DISP, 108, GOLD + (255,)); l2 = TL('ΤΗΣ ΕΝΗΜΕΡΩΣΗΣ.', DISP, 108, GOLD + (255,))
        reveal(fr, l1, W / 2 - l1.size[0] / 2, 1050, prog(lt, .8, 1.1))
        reveal(fr, l2, W / 2 - l2.size[0] / 2, 1158, prog(lt, .9, 1.2))
        pb = back(prog(lt, 1.3, 1.7))
        if pb > .01:
            bw = int(500 * pb); put(fr, self.badge.resize((bw, int(bw * self.badge.size[1] / self.badge.size[0])), Image.LANCZOS), W / 2, 1380)
        put(fr, TL('Δωρεάν  ·  iPhone  ·  iPad  ·  Apple Watch', BD, 34, (170, 166, 156, 255)), W / 2, 1495, 'mm', eo(prog(lt, 1.6, 2.0)))
        return fr

    def raw(self, t):
        if t < T['mani']: fr = self.lock_screen(t)
        elif t < T['phone']: fr = self.manifesto(t)
        elif t < T['lineup']: fr = self.phone(t)
        elif t < T['carousel']: fr = self.lineup(t)
        elif t < T['ipad']: fr = self.carousel(t)
        elif t < T['count']: fr = self.ipad(t)
        elif t < T['watch']: fr = self.countdown(t)
        elif t < T['end']: fr = self.every(t)
        else: fr = self.end(t)
        blade(fr, t)
        return fr

    def frame(self, t, fi):
        a = np.asarray(self.raw(t), np.float32)
        ox, oy = (fi * 17) % 64, (fi * 29) % 64
        a = a * self.vig + self.noise[oy:oy + H, ox:ox + W, None]
        return np.clip(a, 0, 255).astype(np.uint8)


def main(src, badge, logos, out):
    film = Film(src, badge, logos.split(','))
    only = os.environ.get('ONLY_T')
    if only:
        for s in only.split(','):
            t = float(s); Image.fromarray(film.frame(t, int(t * FPS))).save(f'{out}_{s}.png')
        return
    wav = out + '.wav'; build_audio(wav)
    ff = subprocess.Popen(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-',
                           '-i', wav, '-c:v', 'libx264', '-preset', 'slow', '-crf', '21', '-maxrate', '18M', '-bufsize', '36M', '-pix_fmt', 'yuv420p',
                           '-profile:v', 'high', '-c:a', 'aac', '-b:a', '256k', '-shortest', '-movflags', '+faststart', out], stdin=subprocess.PIPE)
    for fi in range(int(DUR * FPS)):
        t = fi / FPS
        ff.stdin.write(film.frame(t, fi).tobytes())
        if fi % 150 == 0: print(f'{t:5.1f}″', flush=True)
    ff.stdin.close(); ff.wait(); os.remove(wav)
    print('✓', out)


if __name__ == '__main__':
    main(*sys.argv[1:5])
