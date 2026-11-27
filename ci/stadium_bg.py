#!/usr/bin/env python3
"""🏟 Φόντο «νυχτερινό γήπεδο»: προβολείς με δέσμες φωτός, καπνός/ομίχλη, bokeh, γήπεδο σε προοπτική.
Όλο ζωγραφισμένο από κώδικα (χωρίς φωτογραφίες τρίτων → χωρίς θέματα άδειας). Χρώματα ΑΕΚ (μαύρο/κίτρινο).

    from stadium_bg import stadium
    img = stadium(W, H, seed=4)          # PIL RGB
"""
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

GOLD = np.array([249, 207, 28], np.float32) / 255
WARM = np.array([255, 236, 190], np.float32) / 255


def fractal(w, h, rng, octaves=5, base=6):
    """Θόρυβος σε στρώσεις (για καπνό)."""
    out = np.zeros((h, w), np.float32); amp = 1.0; tot = 0
    for o in range(octaves):
        n = base * 2 ** o
        small = Image.fromarray((rng.random((max(2, int(n * h / w)), n)) * 255).astype(np.uint8))
        out += amp * np.asarray(small.resize((w, h), Image.BICUBIC), np.float32) / 255
        tot += amp; amp *= .5
    out /= tot
    return np.clip((out - .35) / .4, 0, 1)


def blur(a, r):
    im = Image.fromarray(np.clip(a * 255, 0, 255).astype(np.uint8))
    return np.asarray(im.filter(ImageFilter.GaussianBlur(r)), np.float32) / 255


def stadium(W, H, seed=4, horizon=.62, tower_y=.17):
    rng = np.random.default_rng(seed)
    s = W / 1080  # κλίμακα
    yy = np.linspace(0, 1, H)[:, None]
    # βάση: σχεδόν μαύρο με ζεστό τόνο στο ύψος του ορίζοντα
    img = np.zeros((H, W, 3), np.float32)
    img += np.array([10, 10, 9], np.float32) / 255
    glow_h = np.exp(-((yy - horizon) / .16) ** 2)
    img += glow_h[..., None] * GOLD * .10

    # γήπεδο σε προοπτική κάτω από τον ορίζοντα (πολύ σκούρο πράσινο-μαύρο, με γραμμές)
    hy = int(H * horizon)
    pitch = Image.new('L', (W, H), 0); pd = ImageDraw.Draw(pitch)
    vx = W / 2; vy = hy - 260 * s  # σημείο φυγής
    for i in range(-9, 10):  # λωρίδες γρασιδιού
        x_b = W / 2 + i * 260 * s
        if i % 2 == 0:
            x_b2 = W / 2 + (i + 1) * 260 * s
            def at(xb, y): return vx + (xb - vx) * (y - vy) / (H - vy)
            pd.polygon([(at(x_b, hy), hy), (at(x_b2, hy), hy), (x_b2, H), (x_b, H)], fill=255)
    stripes = np.asarray(pitch, np.float32) / 255
    below = (np.arange(H)[:, None] >= hy).astype(np.float32)
    grass = np.array([9, 15, 10], np.float32) / 255
    depth = np.clip((yy - horizon) / (1 - horizon), 0, 1)
    img = img * (1 - below[..., None]) + below[..., None] * (grass * (.75 + .25 * stripes[..., None]) * (.5 + .9 * depth[..., None]) + np.array([10, 10, 9], np.float32) / 255 * .4)
    lines = Image.new('L', (W, H), 0); ld = ImageDraw.Draw(lines)
    ld.line([(0, hy + 2), (W, hy + 2)], fill=120, width=int(3 * s))
    for k in (0.33, 0.62):  # οριζόντιες γραμμές σε προοπτική
        y = hy + (H - hy) * k ** 1.6
        ld.line([(0, y), (W, y)], fill=70, width=max(1, int(3 * s * (.5 + k))))
    ld.ellipse([W / 2 - 520 * s, hy + 120 * s, W / 2 + 520 * s, hy + 420 * s], outline=70, width=int(4 * s))
    ln = blur(np.asarray(lines, np.float32) / 255, 1.2 * s)
    img += ln[..., None] * WARM * .10

    # προβολείς: δύο «πύργοι» πάνω αριστερά/δεξιά, κάθε πύργος = πλέγμα από λάμπες
    light = np.zeros((H, W), np.float32)
    beams = np.zeros((H, W), np.float32)
    towers = [(W * .10, H * tower_y, 1), (W * .90, H * (tower_y - .02), -1)]
    for tx, ty, side in towers:
        bulbs = Image.new('L', (W, H), 0); bd = ImageDraw.Draw(bulbs)
        for r_ in range(3):
            for c_ in range(5):
                x = tx + (c_ - 2) * 34 * s; y = ty + r_ * 30 * s
                rr = 9 * s; bd.ellipse([x - rr, y - rr, x + rr, y + rr], fill=255)
        b = np.asarray(bulbs, np.float32) / 255
        light += b * 1.0 + blur(b, 10 * s) * 2.2 + blur(b, 45 * s) * 2.0 + blur(b, 140 * s) * 1.4
        # δέσμη: ακτίνες (god rays) από τον πύργο προς το κέντρο του γηπέδου
        Y, X = np.mgrid[0:H, 0:W].astype(np.float32)
        tgt_x = W / 2 + side * 60 * s; tgt_y = H * (horizon + .05)
        ang0 = math.atan2(tgt_y - ty, tgt_x - tx)
        ang = np.arctan2(Y - ty, X - tx) - ang0
        spread = .30
        cone = np.exp(-(ang / spread) ** 2)
        # ραβδώσεις: θόρυβος κατά μήκος της γωνίας
        nrays = 90; ray = rng.random(nrays + 3).astype(np.float32)
        ray = np.convolve(ray, np.ones(2) / 2, 'same')
        u = np.clip((ang / (2 * spread) + .5) * nrays, 0, nrays)
        i0 = u.astype(int); fr_ = u - i0
        streak = ray[i0] * (1 - fr_) + ray[np.minimum(i0 + 1, nrays)] * fr_
        dist = np.sqrt((X - tx) ** 2 + (Y - ty) ** 2) / (H * .9)
        fall = np.clip(1 - dist, 0, 1) ** 1.4
        beams += cone * (.35 + .85 * streak ** 2) * fall
        # flare: οριζόντια λάμψη πάνω στους προβολείς
        fl = np.exp(-((Y - ty - 30 * s) / (6 * s)) ** 2) * np.exp(-((X - tx) / (150 * s)) ** 2)
        light += fl * 1.6
    smoke = fractal(W, H, rng, 6, 4)
    smoke2 = fractal(W, H, rng, 5, 3)
    haze = (.55 + .8 * smoke) * beams
    img += haze[..., None] * WARM * .34
    img += haze[..., None] * GOLD * .38
    # ομίχλη στο ύψος του ορίζοντα (καπνός από τις κερκίδες)
    fog = smoke2 * np.exp(-((yy - (horizon - .03)) / .10) ** 2)
    img += fog[..., None] * GOLD * .12
    img += light[..., None] * WARM * .55

    # bokeh: θολά φωτάκια κερκίδας γύρω από τον ορίζοντα
    bok = Image.new('L', (W, H), 0); bkd = ImageDraw.Draw(bok)
    for _ in range(int(70)):
        x = rng.random() * W; y = H * (horizon - .10 + rng.random() * .14)
        r = (3 + rng.random() ** 4 * 16) * s; a = int(30 + rng.random() ** 2 * 120)
        bkd.ellipse([x - r, y - r, x + r, y + r], fill=a)
    bk = blur(np.asarray(bok, np.float32) / 255, 3 * s)
    img += bk[..., None] * (GOLD * .75 + WARM * .25) * .45
    # σπίθες/σκόνη στον αέρα μέσα στις δέσμες
    dust = np.zeros((H, W), np.float32)
    idx = rng.integers(0, H * W, int(1400 * s * s))
    dust.flat[idx] = rng.random(len(idx))
    dust = blur(dust, 1.0 * s) * 6 * beams
    img += dust[..., None] * WARM * .9

    # tone map (απαλό «κάψιμο» στα φώτα) + βινιέτα
    img = 1 - np.exp(-img * 1.2)
    img = np.clip(img, 0, 1) ** 1.12  # λίγο πιο βαθιά μαύρα
    Y, X = np.mgrid[0:H, 0:W].astype(np.float32)
    d = np.sqrt(((X - W / 2) / (W * .8)) ** 2 + ((Y - H * .5) / (H * .75)) ** 2)
    img *= np.clip(1.1 - .5 * d ** 2, .45, 1)[..., None]
    return Image.fromarray(np.clip(img * 255, 0, 255).astype(np.uint8))


if __name__ == '__main__':
    import sys
    stadium(1080, 1920, int(sys.argv[2]) if len(sys.argv) > 2 else 4).save(sys.argv[1])
