#!/usr/bin/env python3
"""🎬 Βίντεο προώθησης για social (Reels / TikTok / Shorts), 1080×1920, 30fps, ~25″, με δικό του ρυθμό (120 BPM).

python3 ci/promo.py <φάκελος screenshots του ci/appstore.sh> <badge.png App Store> <έξοδος.mp4>
Δομή (έρευνα 26/11): αγκίστρι <1,5″ · πλάνο ανά 2–3″ πάνω στον ρυθμό · κείμενο που διαβάζεται χωρίς ήχο ·
κινητό σε κίνηση με τις αληθινές οθόνες · «Κατέβασέ το» στο τέλος. Κείμενα μέσα στη «ζώνη ασφαλείας»
(όχι στο πάνω 14% και στο κάτω ~25%, εκεί είναι τα κουμπιά της πλατφόρμας). Κεφαλαία χωρίς τόνους.
"""
import os, sys, math, wave, subprocess, random
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS = os.path.join(ROOT, 'Resources', 'Fonts')
ASSETS = os.path.join(ROOT, 'iOS', 'Assets.xcassets')
W, H, FPS = 1080, 1920, 30
BPM = 120; BEAT = 60 / BPM
GOLD, INK, WHITE, TEXT2 = (249, 207, 28), (11, 11, 10), (255, 255, 255), (207, 203, 190)
DUR = 25.0


def font(n, s): return ImageFont.truetype(os.path.join(FONTS, n), int(s))
def clamp(x, a=0.0, b=1.0): return max(a, min(b, x))
def ease_out(t): return 1 - (1 - clamp(t)) ** 3
def ease_in_out(t): t = clamp(t); return 3 * t * t - 2 * t * t * t
def ease_back(t):
    t = clamp(t); c = 1.70158
    return 1 + (c + 1) * (t - 1) ** 3 + c * (t - 1) ** 2
def ease_expo(t): t = clamp(t); return 1 if t == 1 else 1 - 2 ** (-10 * t)
def prog(t, a, b): return clamp((t - a) / (b - a))


# ───────────── Ήχος: δικός μας ρυθμός (kick / clap / hats / bass / riser / whoosh / impact) ─────────────
SR = 44100

def audio(path, hits):
    n = int(SR * (DUR + 0.5)); out = np.zeros(n)
    t = np.arange(n) / SR
    def add(sig, at, g=1.0):
        i = int(at * SR); j = min(n, i + len(sig))
        if i < n: out[i:j] += g * sig[:j - i]
    def env(L, a=0.002, d=0.2):
        x = np.arange(int(L * SR)) / SR
        return np.minimum(1, x / a) * np.exp(-x / d)
    rng = np.random.default_rng(7)
    kick_t = np.arange(int(0.45 * SR)) / SR
    kick = np.sin(2 * np.pi * (45 * kick_t + 90 * (1 - np.exp(-kick_t * 30)) / 30 * 1)) * np.exp(-kick_t * 7)
    kick = np.tanh(kick * 2.2)
    clap = rng.standard_normal(int(0.25 * SR)) * env(0.25, 0.001, 0.06)
    hat = rng.standard_normal(int(0.06 * SR)); hat = np.diff(np.concatenate([[0], hat])) * env(0.06, 0.0005, 0.015)
    beats = int(DUR / BEAT)
    drop = 2.0  # ο ρυθμός μπαίνει γεμάτος μετά το αγκίστρι
    for b in range(beats):
        at = b * BEAT
        if at < drop:  # αγκίστρι: χτύπημα σε κάθε λέξη
            add(kick, at, 0.9); continue
        if at >= DUR - 3.2:  # τέλος: αραιό
            if b % 2 == 0: add(kick, at, 0.8)
            continue
        add(kick, at, 1.0)
        if b % 2 == 1: add(clap, at, 0.55)
        add(hat, at + BEAT / 2, 0.35); add(hat, at + BEAT / 4, 0.12); add(hat, at + 3 * BEAT / 4, 0.12)
    # μπάσο (Λα ελάσσονα: A F C G) σε όγδοα, από το drop
    notes = [55.0, 43.65, 65.41, 49.0]
    for b in range(int(drop / BEAT), int((DUR - 3.2) / BEAT)):
        f = notes[(b // 8) % 4]
        for h in (0, 0.5):
            L = BEAT / 2; x = np.arange(int(L * SR)) / SR
            s = np.sign(np.sin(2 * np.pi * f * x)) * 0.5 + np.sin(2 * np.pi * f * x)
            s = s * np.minimum(1, x / 0.005) * np.exp(-x / 0.18)
            add(np.tanh(s * 1.5) * 0.28, b * BEAT + h * BEAT)
    # pad που απλώνεται (συγχορδίες) στο τέλος
    pad_t0 = DUR - 3.6; L = 3.6; x = np.arange(int(L * SR)) / SR
    pad = sum(np.sin(2 * np.pi * f * x) for f in (220, 261.63, 329.63, 440)) / 4
    add(pad * np.minimum(1, x / 0.4) * np.exp(-x / 2.5) * 0.35, pad_t0)
    # riser πριν το drop + whoosh / impact στις αλλαγές πλάνων
    L = drop; x = np.arange(int(L * SR)) / SR
    riser = rng.standard_normal(len(x)) * (x / L) ** 2
    add(np.convolve(riser, np.ones(8) / 8, 'same') * 0.25, 0)
    imp = np.sin(2 * np.pi * 40 * kick_t) * np.exp(-kick_t * 4) + rng.standard_normal(len(kick_t)) * np.exp(-kick_t * 25) * 0.6
    for h in hits:
        L = 0.35; x = np.arange(int(L * SR)) / SR
        wh = rng.standard_normal(len(x)) * np.sin(np.pi * x / L) ** 2
        wh = np.convolve(wh, np.ones(30) / 30, 'same')
        add(wh * 0.5, max(0, h - 0.3))
        add(imp * 0.45, h)
    add(imp * 0.8, drop)
    out = out / (np.max(np.abs(out)) + 1e-9) * 0.89
    out[-int(0.6 * SR):] *= np.linspace(1, 0, int(0.6 * SR))
    pcm = (out * 32767).astype(np.int16)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())


# ───────────── Εικόνα ─────────────

def load_bg():
    bg = Image.new('RGB', (W, H), INK)
    try:
        hero = Image.open(os.path.join(ASSETS, 'HeroBg.imageset', 'HeroBg.jpg')).convert('RGB')
        k = H / hero.size[1]; hero = hero.resize((int(hero.size[0] * k), H))
        hero = hero.crop(((hero.size[0] - W) // 2, 0, (hero.size[0] - W) // 2 + W, H)).filter(ImageFilter.GaussianBlur(6))
        bg = Image.blend(hero, bg, 0.84)
    except Exception as e:
        print('χωρίς φόντο:', e)
    return bg


STRIPES = None
def stripes_layer():
    global STRIPES
    if STRIPES is None:
        S = Image.new('L', (W + 400, H + 400), 0); d = ImageDraw.Draw(S)
        for x in range(-H, W + H + 400, 110):
            d.line([(x, H + 400), (x + H + 400, 0)], fill=255, width=6)
        STRIPES = S
    return STRIPES


def background(base, t, pulse):
    im = base.copy()
    off = int((t * 60) % 110)  # οι γραμμές κινούνται αργά
    m = stripes_layer().crop((off, off, off + W, off + H)).point(lambda v: v * (18 + 22 * pulse) // 255)
    im.paste(GOLD, (0, 0), m)
    g = Image.new('L', (W // 4, H // 4), 0)
    r = 0.55 + 0.08 * pulse
    ImageDraw.Draw(g).ellipse([W / 4 * (0.5 - r), H / 4 * (0.55 - r * 0.5), W / 4 * (0.5 + r), H / 4 * (0.55 + r * 0.5)], fill=int(55 + 35 * pulse))
    g = g.filter(ImageFilter.GaussianBlur(40)).resize((W, H))
    im.paste(GOLD, (0, 0), g)
    return im


class Phone:
    """Κινητό με «τρύπα» για την οθόνη: πλαίσιο + μάσκα· η οθόνη αλλάζει ανά καρέ (κύλιση/ζουμ)."""
    def __init__(self, h):
        self.sh = h; self.sw = int(h * 1320 / 2868)
        b = int(h * 0.016); self.b = b
        self.W, self.H = self.sw + 2 * b, h + 2 * b
        R = int(self.W * 0.17)
        f = Image.new('RGBA', (self.W, self.H), (0, 0, 0, 0)); d = ImageDraw.Draw(f)
        d.rounded_rectangle([0, 0, self.W - 1, self.H - 1], R, fill=(70, 69, 65, 255))
        d.rounded_rectangle([3, 3, self.W - 4, self.H - 4], R - 3, fill=(16, 16, 15, 255))
        self.mask = Image.new('L', (self.sw, h), 0)
        ImageDraw.Draw(self.mask).rounded_rectangle([0, 0, self.sw - 1, h - 1], R - b, fill=255)
        hole = Image.new('L', (self.W, self.H), 255); hole.paste(0, (b, b), self.mask)
        f.putalpha(Image.composite(f.split()[3], Image.new('L', f.size, 0), hole))
        iw, ih = int(self.sw * 0.3), int(self.sw * 0.085)
        ImageDraw.Draw(f).rounded_rectangle([(self.W - iw) // 2, b + int(h * 0.012), (self.W + iw) // 2, b + int(h * 0.012) + ih], ih // 2, fill=(0, 0, 0, 255))
        self.frame = f
        sh = Image.new('L', (self.W + 160, self.H + 160), 0)
        ImageDraw.Draw(sh).rounded_rectangle([80, 100, self.W + 80, self.H + 100], R, fill=200)
        self.shadow = sh.filter(ImageFilter.GaussianBlur(40))

    def render(self, screen):
        im = Image.new('RGBA', (self.W, self.H), (0, 0, 0, 0))
        im.paste(screen.resize((self.sw, self.sh), Image.BILINEAR), (self.b, self.b), self.mask)
        im.alpha_composite(self.frame)
        return im


def screen_view(shot, zoom=1.0, cx=0.5, cy=0.5, scroll=0.0):
    """Τμήμα του screenshot (ζουμ γύρω από cx,cy ή κύλιση προς τα κάτω σε pixels της πηγής)."""
    sw, sh = shot.size
    w, h = sw / zoom, sh / zoom
    x = clamp(cx * sw - w / 2, 0, sw - w); y = clamp(cy * sh - h / 2 + scroll, 0, sh - h)
    return shot.crop((int(x), int(y), int(x + w), int(y + h)))


def put_phone(frame, ph_img, phone, cx, cy, scale=1.0, angle=0.0, alpha=1.0):
    im = ph_img
    if scale != 1.0:
        im = im.resize((max(1, int(im.size[0] * scale)), max(1, int(im.size[1] * scale))), Image.BILINEAR)
    sh = phone.shadow.resize((int(phone.shadow.size[0] * scale), int(phone.shadow.size[1] * scale)))
    if angle:
        im = im.rotate(angle, resample=Image.BICUBIC, expand=True); sh = sh.rotate(angle, expand=True)
    if alpha < 1:
        a = im.split()[3].point(lambda v: int(v * alpha)); im.putalpha(a); sh = sh.point(lambda v: int(v * alpha))
    frame.paste((0, 0, 0), (int(cx - sh.size[0] / 2), int(cy - sh.size[1] / 2)), sh)
    frame.paste(im, (int(cx - im.size[0] / 2), int(cy - im.size[1] / 2)), im)


def text_c(d, y, s, f, fill, x=None, track=0):
    w = d.textlength(s, font=f) + track * (len(s) - 1)
    x0 = (W - w) / 2 if x is None else x
    if track:
        for ch in s:
            d.text((x0, y), ch, font=f, fill=fill); x0 += d.textlength(ch, font=f) + track
    else:
        d.text((x0, y), s, font=f, fill=fill)
    return w


def slam(frame, s, t, t0, y, size, fill, out_t=None):
    """Λέξη που «πέφτει» (μεγάλη → κανονική) με λίγο κούνημα· σβήνει στο out_t."""
    if t < t0: return
    p = prog(t, t0, t0 + 0.18)
    sc = 1.0 + 0.55 * (1 - ease_expo(p))
    a = 1.0 if out_t is None else 1 - prog(t, out_t, out_t + 0.12)
    if a <= 0: return
    f = font('SofiaSans-Black.ttf', size)
    tmp = Image.new('L', (W * 2, int(size * 1.4)), 0); dd = ImageDraw.Draw(tmp)
    tw = dd.textlength(s, font=f); dd.text(((W * 2 - tw) / 2, 0), s, font=f, fill=255)
    bb = tmp.getbbox()
    if not bb: return
    tmp = tmp.crop(bb)
    tmp = tmp.resize((max(1, int(tmp.size[0] * sc)), max(1, int(tmp.size[1] * sc))), Image.BILINEAR)
    sx = (random.random() - 0.5) * 14 * (1 - p); sy = (random.random() - 0.5) * 14 * (1 - p)
    m = tmp.point(lambda v: int(v * a * min(1, p * 4)))
    frame.paste(fill, (int((W - tmp.size[0]) / 2 + sx), int(y - tmp.size[1] / 2 + sy)), m)


def caption(frame, t, t0, t1, l1, l2=None, sub=None, y=330):
    """Τίτλος σκηνής: γραμμές που ανεβαίνουν με «μάσκα» + κίτρινη γραμμούλα· φεύγουν στο t1."""
    if t < t0 or t > t1 + 0.2: return
    d = ImageDraw.Draw(frame)
    pin = ease_out(prog(t, t0, t0 + 0.35)); pout = ease_in_out(prog(t, t1 - 0.05, t1 + 0.15))
    a = pin * (1 - pout)
    big = font('SofiaSans-Black.ttf', 128)
    for i, (s, col) in enumerate(((l1, GOLD), (l2, WHITE))):
        if not s: continue
        pi = ease_out(prog(t, t0 + i * 0.08, t0 + i * 0.08 + 0.35))
        layer = Image.new('L', (W, 150), 0); ImageDraw.Draw(layer).text(((W - d.textlength(s, font=big)) / 2, 150 * (1 - pi) - 4), s, font=big, fill=int(255 * a))
        frame.paste(col, (0, int(y + i * 128 - 20 * pout)), layer)
    yy = y + (2 if l2 else 1) * 128 + 18
    bw = int(90 * ease_out(prog(t, t0 + 0.15, t0 + 0.5)) * (1 - pout))
    if bw > 2: d.rounded_rectangle([(W - bw) / 2, yy, (W + bw) / 2, yy + 8], 4, fill=GOLD)
    if sub:
        sf = font('Manrope-Bold.ttf', 40)
        ps = ease_out(prog(t, t0 + 0.25, t0 + 0.6)) * (1 - pout)
        layer = Image.new('L', (W, 60), 0); ImageDraw.Draw(layer).text(((W - d.textlength(sub, font=sf)) / 2, 2), sub, font=sf, fill=int(255 * ps))
        frame.paste(TEXT2, (0, int(yy + 30)), layer)


def main(src, badge_path, out):
    random.seed(3)
    shots = {k: Image.open(os.path.join(src, f)).convert('RGB') for k, f in {
        'home': 'iphone69-1.png', 'score': 'iphone69-2.png', 'timeline': 'iphone69-3.png', 'lineup': 'iphone69-4.png',
        'pre': 'iphone69-5.png', 'matches': 'iphone69-6.png', 'table': 'iphone69-7.png', 'post': 'iphone69-8.png',
        'basket': 'iphone69-9.png', 'watch': 'watch-2.png', 'watch1': 'watch-1.png'}.items()}
    icon = Image.open(os.path.join(ASSETS, 'AppIcon.appiconset', 'icon-1024.png')).convert('RGB')
    badge = Image.open(badge_path).convert('RGBA')
    base = load_bg()
    P = Phone(1180)

    # χρονοδιάγραμμα (δευτερόλεπτα, πάνω στον ρυθμό 0,5″)
    S = dict(hook=0.0, intro=2.0, score=4.0, timeline=7.0, lineup=10.0, pre=13.0, montage=16.0, watch=19.0, end=21.5)
    hits = [S[k] for k in ('score', 'timeline', 'lineup', 'pre', 'montage', 'watch', 'end')] + [16.5, 17.0, 17.5, 18.0]
    wav = out + '.wav'; audio(wav, hits)

    ff = subprocess.Popen(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-',
                           '-i', wav, '-c:v', 'libx264', '-preset', 'medium', '-crf', '17', '-pix_fmt', 'yuv420p', '-profile:v', 'high',
                           '-c:a', 'aac', '-b:a', '192k', '-shortest', '-movflags', '+faststart', out], stdin=subprocess.PIPE)
    N = int(DUR * FPS)
    for fi in range(N):
        t = fi / FPS
        beat_ph = (t % BEAT) / BEAT
        pulse = math.exp(-beat_ph * 5) if t >= S['intro'] else 0.4
        fr = background(base, t, pulse)
        d = ImageDraw.Draw(fr)

        # 0–2″ ΑΓΚΙΣΤΡΟ: λέξεις στον ρυθμό, μετά «ΟΛΗ Η ΑΕΚ»
        if t < S['intro']:
            words = [('ΓΚΟΛ', GOLD), ('ΣΚΟΡ', WHITE), ('ΣΥΝΘΕΣΕΙΣ', GOLD), ('LIVE', WHITE)]
            k = min(3, int(t / BEAT))
            if t < 1.75:
                fr.paste(INK if k % 2 else (20, 18, 8), (0, 0, W, H)) if (t % BEAT) < 0.05 else None
                slam(fr, words[k][0], t, k * BEAT, 900, 250 if k != 2 else 175, words[k][1])
                d.text(((W - d.textlength('0' + str(k + 1), font=font('Manrope-ExtraBold.ttf', 34))) / 2, 1120), '0' + str(k + 1) + ' / 04', font=font('Manrope-ExtraBold.ttf', 34), fill=GOLD)
            else:
                fr.paste(GOLD, (0, 0, W, H))  # φλας πριν το drop

        # 2–4″ «ΟΛΗ Η ΑΕΚ ΣΤΟ ΚΙΝΗΤΟ ΣΟΥ» + κινητό ανεβαίνει
        if S['intro'] <= t < S['score'] + 0.4:
            caption(fr, t, S['intro'], S['score'] - 0.15, 'ΟΛΗ Η ΑΕΚ', 'ΣΤΟ ΚΙΝΗΤΟ ΣΟΥ')
            p = ease_back(prog(t, S['intro'] + 0.1, S['intro'] + 0.8))
            ph = P.render(screen_view(shots['home'], scroll=prog(t, 2.6, 4.0) * 500))
            put_phone(fr, ph, P, W / 2, 2050 - 760 * p + 400 * prog(t, S['score'] - 0.2, S['score'] + 0.4), 0.98, -4 * (1 - p))

        # scenes: (αρχή, τέλος, screenshot, τίτλος, υπότιτλος, κίνηση)
        scenes = [
            (S['score'], S['timeline'], 'score', ('LIVE', 'ΣΚΟΡ'), 'Κάθε γκολ, τη στιγμή που μπαίνει', 'zoom'),
            (S['timeline'], S['lineup'], 'timeline', ('ΚΑΘΕ', 'ΦΑΣΗ'), 'Γκολ, κάρτες, αλλαγές — λεπτό προς λεπτό', 'scroll'),
            (S['lineup'], S['pre'], 'lineup', ('ΟΙ ΣΥΝΘΕΣΕΙΣ', 'ΣΤΟ ΓΗΠΕΔΟ'), 'Ενδεκάδες και βαθμολογίες παικτών', 'tilt'),
            (S['pre'], S['montage'], 'pre', ('ΠΡΙΝ', 'ΤΗ ΣΕΝΤΡΑ'), 'Αντίστροφη μέτρηση και κανάλια', 'zoom2'),
        ]
        for (a, b, key, (l1, l2), sub, mv) in scenes:
            if a - 0.01 <= t < b + 0.01:
                lt = t - a; L = b - a
                caption(fr, t, a + 0.05, b - 0.15, l1, l2, sub)
                pin = ease_out(prog(t, a, a + 0.45)); pout = ease_in_out(prog(t, b - 0.3, b))
                zoom, cy, scroll, ang = 1.0, 0.5, 0, 0
                if mv == 'zoom': zoom = 1 + 0.55 * ease_in_out(prog(lt, 1.2, 2.4)); cy = 0.24
                if mv == 'zoom2': zoom = 1 + 0.5 * ease_in_out(prog(lt, 1.0, 2.2)); cy = 0.55
                if mv == 'scroll': scroll = 900 * ease_in_out(prog(lt, 0.6, 2.6))
                if mv == 'tilt': ang = 4 * math.sin(lt * 1.5)
                ph = P.render(screen_view(shots[key], zoom=zoom, cy=cy, scroll=scroll))
                x = W / 2 + (1 - pin) * 900 * (1 if scenes.index((a, b, key, (l1, l2), sub, mv)) % 2 else -1) - pout * 900 * (1 if scenes.index((a, b, key, (l1, l2), sub, mv)) % 2 else -1)
                put_phone(fr, ph, P, x, 1300 + 16 * math.sin(lt * 2), 0.98, ang + (1 - pin) * 10)

        # 16–19″ ΜΟΝΤΑΖ: 4 οθόνες, μία ανά 0,5″ (×2), με τίτλο που αλλάζει
        if S['montage'] <= t < S['watch']:
            lt = t - S['montage']
            items = [('matches', 'ΠΡΟΓΡΑΜΜΑ'), ('table', 'ΒΑΘΜΟΛΟΓΙΕΣ'), ('post', 'ΕΙΔΗΣΕΙΣ'), ('basket', 'ΜΠΑΣΚΕΤ')]
            k = int(lt / 0.75) % 4
            key, word = items[k]
            lp = (lt % 0.75) / 0.75
            slam(fr, word, t, S['montage'] + int(lt / 0.75) * 0.75, 420, 150, GOLD if k % 2 == 0 else WHITE)
            ph = P.render(screen_view(shots[key], zoom=1 + 0.08 * lp))
            put_phone(fr, ph, P, W / 2, 1290, 0.95 + 0.03 * ease_out(lp * 3), (-3 if k % 2 else 3) * (1 - ease_out(lp * 3)))
            d.text(((W - d.textlength('ΚΑΙ ΟΛΑ ΤΑ ΤΜΗΜΑΤΑ', font=font('Manrope-ExtraBold.ttf', 36))) / 2, 540), 'ΚΑΙ ΟΛΑ ΤΑ ΤΜΗΜΑΤΑ', font=font('Manrope-ExtraBold.ttf', 36), fill=TEXT2)

        # 19–21,5″ APPLE WATCH + LIVE ACTIVITY
        if S['watch'] <= t < S['end'] + 0.3:
            caption(fr, t, S['watch'] + 0.05, S['end'] - 0.15, 'ΚΑΙ ΣΤΟ', 'APPLE WATCH', 'Σκορ στον καρπό και στην οθόνη κλειδώματος')
            p = ease_back(prog(t, S['watch'], S['watch'] + 0.5)); pout = ease_in_out(prog(t, S['end'] - 0.2, S['end'] + 0.2))
            wimg = shots['watch' if t < S['watch'] + 1.25 else 'watch1']
            ww = int(560 * (0.6 + 0.4 * p)); wh = int(ww * wimg.size[1] / wimg.size[0])
            case = Image.new('RGBA', (ww + 70, wh + 70), (0, 0, 0, 0)); cd = ImageDraw.Draw(case)
            cd.rounded_rectangle([0, 0, ww + 69, wh + 69], int(ww * 0.26), fill=(60, 59, 55, 255))
            cd.rounded_rectangle([6, 6, ww + 63, wh + 63], int(ww * 0.24), fill=(8, 8, 8, 255))
            m = Image.new('L', (ww, wh), 0); ImageDraw.Draw(m).rounded_rectangle([0, 0, ww - 1, wh - 1], int(ww * 0.2), fill=255)
            case.paste(wimg.resize((ww, wh)), (35, 35), m)
            y0 = 1290 + (1 - p) * 200 + pout * 1200
            band = Image.new('RGBA', (int(ww * 0.74), 1500), (0, 0, 0, 0))
            ImageDraw.Draw(band).rounded_rectangle([0, 0, band.size[0] - 1, 1499], 60, fill=(42, 41, 38, 255))
            for yy in range(40, 1500, 46): ImageDraw.Draw(band).line([(30, yy), (band.size[0] - 30, yy)], fill=(52, 51, 47, 255), width=4)
            fr.paste(band, (int(W / 2 - band.size[0] / 2), int(y0 - 470)), band)
            fr.paste(case, (int(W / 2 - case.size[0] / 2), int(y0 - case.size[1] / 2)), case)
            # κουκκίδα LIVE που αναβοσβήνει
            if int(t * 4) % 2 == 0:
                d.ellipse([W / 2 - 236, 761, W / 2 - 214, 783], fill=(230, 40, 40))
            if t < S['end'] - 0.15: d.text((W / 2 - 200, 754), 'LIVE ACTIVITY · DYNAMIC ISLAND', font=font('Manrope-ExtraBold.ttf', 28), fill=WHITE)

        # 21,5–25″ ΤΕΛΟΣ: εικονίδιο, όνομα, «ΚΑΤΕΒΑΣΕ ΤΟ ΔΩΡΕΑΝ», σήμα App Store
        if t >= S['end']:
            lt = t - S['end']
            if lt < 0.08: fr.paste(GOLD, (0, 0, W, H))
            p = ease_back(prog(lt, 0.05, 0.55))
            s = int(300 * p)
            if s > 4:
                ic = icon.resize((s, s), Image.LANCZOS); m = Image.new('L', (s, s), 0)
                ImageDraw.Draw(m).rounded_rectangle([0, 0, s - 1, s - 1], int(s * 0.225), fill=255)
                glow = Image.new('L', (W, H), 0); ImageDraw.Draw(glow).ellipse([W / 2 - 330, 640 - 330, W / 2 + 330, 640 + 330], fill=int(90 * p))
                fr.paste(GOLD, (0, 0), glow.filter(ImageFilter.GaussianBlur(80)))
                fr.paste(ic, (int(W / 2 - s / 2), int(640 - s / 2)), m)
            slam(fr, 'AEK HUB', t, S['end'] + 0.45, 940, 190, WHITE)
            pa = ease_out(prog(lt, 0.9, 1.3))
            if pa > 0:
                sf = font('SofiaSans-Black.ttf', 84)
                layer = Image.new('L', (W, 110), 0); ImageDraw.Draw(layer).text(((W - d.textlength('ΚΑΤΕΒΑΣΕ ΤΟ ΔΩΡΕΑΝ', font=sf)) / 2, 110 * (1 - pa)), 'ΚΑΤΕΒΑΣΕ ΤΟ ΔΩΡΕΑΝ', font=sf, fill=int(255 * pa))
                fr.paste(GOLD, (0, 1060), layer)
            pb = ease_back(prog(lt, 1.25, 1.75))
            if pb > 0.01:
                bw = int(560 * pb); bh = int(bw * badge.size[1] / badge.size[0])
                bb = badge.resize((max(1, bw), max(1, bh)), Image.LANCZOS)
                fr.paste(bb, (int(W / 2 - bw / 2), int(1260 - bh / 2)), bb)
            pc = ease_out(prog(lt, 1.8, 2.2))
            if pc > 0:
                sf = font('Manrope-Bold.ttf', 38)
                d.text(((W - d.textlength('iPhone · iPad · Apple Watch', font=sf)) / 2, 1400), 'iPhone · iPad · Apple Watch', font=sf, fill=tuple(int(c * pc) for c in TEXT2))

        ff.stdin.write(fr.tobytes())
        if fi % 150 == 0: print(f'{t:5.1f}″', flush=True)
    ff.stdin.close(); ff.wait(); os.remove(wav)
    print('✓', out)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], sys.argv[3])
