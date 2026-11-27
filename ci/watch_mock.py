#!/usr/bin/env python3
"""⌚ Mockup Apple Watch (φωτογραφία σε μπεζ φόντο, ροζ) → ΜΑΥΡΟ ρολόι με τη δική μας οθόνη, χωρίς φόντο (PNG).

python3 ci/watch_mock.py <mockup.png> <screenshot ρολογιού> <έξοδος.png>
Το mockup το έδωσε ο χρήστης (26/11, 1400×934): ομοιόμορφο φόντο (218,207,199), οθόνη ≈ (518,287)–(881,705).
1) φόντο+σκιά = «ουδέτερα» pixels (R−B)/L < 0.108 συνδεδεμένα με τις γωνίες (flood fill) · 2) χρώμα → σκούρο «Midnight»
κρατώντας τη σκίαση · 3) νέα οθόνη με στρογγυλές γωνίες + η γυαλάδα πάνω δεξιά από το πρωτότυπο.
"""
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

def main(mock, screen, out, box=(518, 287, 881, 705)):
    im = Image.open(mock).convert('RGB'); a = np.asarray(im).astype(float); L = a.mean(2)
    r = (a[..., 0] - a[..., 2]) / np.maximum(L, 1)
    m = Image.fromarray((((r < .108) & (L > 60)) * 255).astype(np.uint8)).copy()
    for s in [(0, 0), (im.size[0] - 1, 0), (0, im.size[1] - 1), (im.size[0] - 1, im.size[1] - 1)]:
        if m.getpixel(s) == 255: ImageDraw.floodfill(m, s, 128)
    wm = Image.fromarray(((np.array(m) != 128) * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(5)).filter(ImageFilter.MaxFilter(5))
    wm = np.asarray(wm.filter(ImageFilter.GaussianBlur(1.4))).astype(float) / 255
    k = np.clip((L - 110) / 130, 0, 1.3)
    nl = 8 + k ** 1.25 * 58 + np.clip((L - 232) / 23, 0, 1) * 130
    o = np.stack([nl * .93, nl * .95, nl], 2); o = np.where((L < 40)[..., None], np.minimum(a, 12), o)
    img = Image.fromarray(np.clip(o, 0, 255).astype(np.uint8))
    x0, y0, x1, y1 = box; ins = 10; sw, sh = x1 - x0 + 1 - 2 * ins, y1 - y0 + 1 - 2 * ins
    w = Image.open(screen).convert('RGB'); k2 = max(sw / w.size[0], sh / w.size[1])
    w2 = w.resize((int(w.size[0] * k2) + 1, int(w.size[1] * k2) + 1), Image.LANCZOS)
    w2 = w2.crop(((w2.size[0] - sw) // 2, (w2.size[1] - sh) // 2, (w2.size[0] - sw) // 2 + sw, (w2.size[1] - sh) // 2 + sh))
    mk = Image.new('L', (sw, sh), 0); ImageDraw.Draw(mk).rounded_rectangle([0, 0, sw - 1, sh - 1], 54, fill=255)
    img.paste(w2, (x0 + ins, y0 + ins), mk.filter(ImageFilter.GaussianBlur(.8)))
    g = np.clip((L - 150) / 105, 0, 1); reg = np.zeros_like(g); reg[y0 - 5:y0 + 60, x1 - 110:x1 + 8] = 1
    img.paste((255, 255, 255), (0, 0), Image.fromarray((g * reg * 200).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1)))
    rgba = img.convert('RGBA'); rgba.putalpha(Image.fromarray((wm * 255).astype(np.uint8)))
    rgba.crop(rgba.getbbox()).save(out); print('✓', out)

if __name__ == '__main__':
    main(*sys.argv[1:4])
