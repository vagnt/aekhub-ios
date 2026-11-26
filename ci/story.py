#!/usr/bin/env python3
"""📱 Story (1080×1920) με τις 3 συσκευές μαζί — ίδιο ύφος με το ci/promo.py (μαύρο/κίτρινο, γραμματοσειρές του site).

python3 ci/story.py <φάκελος screenshots του ci/appstore.sh> <badge.png App Store> <έξοδος.png> [watch-mockup.png]
Αποδίδεται σε 2× (2160×3840) και μικραίνει στο τέλος → πεντακάθαρο. Τα σημαντικά μένουν έξω από
το πάνω ~250px και το κάτω ~250px (εκεί είναι τα κουμπιά του Instagram/Facebook story).
"""
import os, sys, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance
import promo as P

S = 2  # υπερδειγματοληψία
W, H = 1080 * S, 1920 * S
P.W, P.H = W, H
GOLD, INK, WHITE = P.GOLD, P.INK, P.WHITE


def main(src, badge, out, watch_mock=None, bg_photo=None):
    L = lambda f: Image.open(os.path.join(src, f)).convert('RGB')
    # οθόνες πιο ζωντανές: λίγο περισσότερο χρώμα/αντίθεση/φως (να «σκάνε» πάνω στο μαύρο)
    def pop(im, c=1.22, k=1.08, b=1.05):
        return ImageEnhance.Brightness(ImageEnhance.Contrast(ImageEnhance.Color(im).enhance(c)).enhance(k)).enhance(b)
    phone_scr, ipad_scr, watch_scr = pop(L('iphone69-2.png')), pop(L('ipad13-1.png')), pop(L('watch-1.png'))
    film = P.Film.__new__(P.Film)  # μόνο για watch_img
    icon = Image.open(os.path.join(P.ASSETS, 'AppIcon.appiconset', 'icon-1024.png')).convert('RGB')
    bdg = Image.open(badge).convert('RGBA')

    # ── φόντο: νυχτερινό γήπεδο (προβολείς, ακτίνες, καπνός, bokeh — stadium_bg.py, χωρίς φωτογραφίες τρίτων) ──
    if bg_photo:  # φωτογραφία του χρήστη (γήπεδο), θολή — για να ξεχωρίζουν κείμενα και συσκευές
        ph_bg = Image.open(bg_photo).convert('RGB')
        k = max(W / ph_bg.size[0], H / ph_bg.size[1]); ph_bg = ph_bg.resize((int(ph_bg.size[0] * k) + 1, int(ph_bg.size[1] * k) + 1), Image.LANCZOS)
        ph_bg = ph_bg.crop(((ph_bg.size[0] - W) // 2, (ph_bg.size[1] - H) // 2, (ph_bg.size[0] - W) // 2 + W, (ph_bg.size[1] - H) // 2 + H))
        fr = ImageEnhance.Brightness(ph_bg.filter(ImageFilter.GaussianBlur(5 * S))).enhance(.88)
    else:
        from stadium_bg import stadium
        fr = stadium(W, H, seed=4, horizon=.64, tower_y=.075)

    # σκούρο «σκέπασμα» πίσω από τα κείμενα (πάνω) για να διαβάζονται πάνω στις ακτίνες
    a = np.asarray(fr, np.float32); yy = np.arange(H)[:, None, None] / H
    a *= np.clip(.72 + (yy - .12) / .30 * .28, .72, 1)
    # «σκηνή»: χρυσή λάμψη πίσω από τις συσκευές + λίμνη φωτός στο γήπεδο κάτω τους
    def soft(box, val, r):
        g = Image.new('L', (W // 8, H // 8), 0); ImageDraw.Draw(g).ellipse([v / 8 for v in box], fill=val)
        return np.asarray(g.filter(ImageFilter.GaussianBlur(r)).resize((W, H), Image.BICUBIC), np.float32)[..., None] / 255
    gold = np.array(GOLD, np.float32); warm = np.array([255, 236, 190], np.float32)
    a += soft([W / 2 - 520 * S, 760 * S, W / 2 + 520 * S, 1500 * S], 120, 22) * gold * .55
    a += soft([W / 2 - 560 * S, 1430 * S, W / 2 + 560 * S, 1590 * S], 170, 12) * warm * .22
    # σκούρο σβήσιμο στο κάτω μέρος: η γραμμή «AEK HUB / App Store» κάθεται καθαρά
    yy = np.arange(H, dtype=np.float32)[:, None, None] / S
    a *= 1 - .72 * np.clip((yy - 1480) / 200, 0, 1)
    fr = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))

    # ── συσκευές σε δικό τους layer (για να φτιάξουμε και αντανάκλαση) ──
    dev = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    pad = P.Device(1000 * S, 2064 / 2752, .03, .06, False); pad.gloss = pad.gloss.point(lambda v: v // 3)
    pad.draw(dev, ipad_scr, 345 * S, 1095 * S, .70, ry=.30, rx=.05, rz=-.02, shadow=.6)
    ph = P.Device(1300 * S, 1320 / 2868, .017, .17, True); ph.gloss = ph.gloss.point(lambda v: v // 3)
    ph.draw(dev, phone_scr, 595 * S, 1145 * S, .55, ry=-.16, rx=.05, rz=.01, shadow=.65)
    if watch_mock:  # φωτορεαλιστικό mockup (μαύρο, με την οθόνη μας ήδη μέσα — βλ. history.md)
        wmk = Image.open(watch_mock).convert('RGBA'); ww = 305 * S
        w = wmk.resize((ww, int(wmk.size[1] * ww / wmk.size[0])), Image.LANCZOS)
        al = w.split()[3]; w = pop(w.convert('RGB'), 1.25, 1.08, 1.06).convert('RGBA'); w.putalpha(al)
    else:
        w = film.watch_img(watch_scr, 270 * S)
    pdw = int(w.size[1] * .15); can = Image.new('L', (w.size[0] + 2 * pdw, w.size[1] + 2 * pdw), 0); can.paste(w.split()[3], (pdw, pdw))
    sh = can.resize((can.size[0] // 6, can.size[1] // 6)).filter(ImageFilter.GaussianBlur(8)).resize(can.size)
    wx, wy = 915 * S, 1265 * S
    dev.paste((0, 0, 0, 255), (int(wx - w.size[0] / 2 - pdw + 24 * S), int(wy - w.size[1] / 2 - pdw + 40 * S)), sh.point(lambda v: int(v * .6)))
    P.put(dev, w, wx, wy)

    # (χωρίς αντανάκλαση: πάνω σε φωτογραφία έβγαζε σκούρα «κουτιά»)
    fr.paste(dev, (0, 0), dev)

    # ── κείμενα ──
    d = ImageDraw.Draw(fr)
    d.ellipse([72 * S, 262 * S, 90 * S, 280 * S], fill=GOLD)
    P.put(fr, P.TL('AEK HUB', P.XB, 30 * S, GOLD + (255,), 5 * S), 104 * S, 271 * S, 'lm')
    t1 = P.TL('ΟΛΗ Η ΑΕΚ.', P.DISP, 150 * S, WHITE + (255,)); t2 = P.TL('ΣΕ ΚΑΘΕ ΣΥΣΚΕΥΗ.', P.DISP, 150 * S, GOLD + (255,))
    k = min(1, 936 * S / max(t1.size[0], t2.size[0]))
    if k < 1:
        t1 = t1.resize((int(t1.size[0] * k), int(t1.size[1] * k)), Image.LANCZOS); t2 = t2.resize((int(t2.size[0] * k), int(t2.size[1] * k)), Image.LANCZOS)
    P.put(fr, t1, 72 * S, 315 * S, 'lt'); P.put(fr, t2, 72 * S, 315 * S + t1.size[1] + 22 * S, 'lt')
    P.put(fr, P.TL('Live σκορ, ειδοποιήσεις και όλα τα τμήματα', P.BD, 36 * S, (200, 196, 185, 255)), 72 * S, 315 * S + t1.size[1] + t2.size[1] + 60 * S, 'lt')
    # chips συσκευών
    x = 72 * S; y = 315 * S + t1.size[1] + t2.size[1] + 125 * S
    for c in ('iPhone', 'iPad', 'Apple Watch'):
        tl = P.TL(c, P.XB, 28 * S, WHITE + (255,), 2 * S)
        cw = tl.size[0] + 44 * S
        d.rounded_rectangle([x, y, x + cw, y + 54 * S], 27 * S, outline=(90, 88, 82), width=2 * S)
        P.put(fr, tl, x + cw / 2, y + 27 * S); x += cw + 14 * S

    # ── κάτω: εικονίδιο + όνομα + App Store ──
    yb = 1665 * S
    s = 116 * S; ic = icon.resize((s, s), Image.LANCZOS).convert('RGBA'); ic.putalpha(P.rounded_mask(s, s, int(s * .225)))
    P.put(fr, ic, 72 * S, yb, 'lm')
    P.put(fr, P.TL('AEK HUB', P.DISP, 74 * S, WHITE + (255,)), 72 * S + s + 26 * S, yb - 22 * S, 'lm')
    P.put(fr, P.TL('Δωρεάν στο App Store', P.BD, 30 * S, (190, 186, 175, 255)), 72 * S + s + 28 * S, yb + 34 * S, 'lm')
    bw = 330 * S; b = bdg.resize((bw, int(bw * bdg.size[1] / bdg.size[0])), Image.LANCZOS)
    P.put(fr, b, W - 72 * S, yb, 'rm')

    # μικραίνει σε 1080×1920 + ελαφρύ «ξεθόλωμα» + πολύ λίγος κόκκος
    out_im = fr.resize((1080, 1920), Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=1.2, percent=70, threshold=2))
    n = (np.random.default_rng(3).standard_normal((1920, 1080, 1)) * 1.6)
    out_im = Image.fromarray(np.clip(np.asarray(out_im, np.float32) + n, 0, 255).astype(np.uint8))
    out_im.save(out, optimize=True); print('✓', out, out_im.size)


if __name__ == '__main__':
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    main(*sys.argv[1:6])
