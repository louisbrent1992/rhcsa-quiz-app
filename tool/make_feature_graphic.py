#!/usr/bin/env python3
"""Generate the Play Store feature graphic (1024x500).

Reuses the icon's prompt glyph so the listing and the launcher icon read as
the same product. Play crops this image differently across placements, so
everything meaningful stays inside a generous margin.

Output:  store/feature_graphic_1024x500.png

Run:  python3 tool/make_feature_graphic.py
"""
import os

from PIL import Image, ImageDraw, ImageFont

from make_icon import glyph, TOP, BOTTOM

W, H = 1024, 500
SS = 3  # supersample, then downscale

BOLD = '/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf'
REG = '/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf'
MONO = '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf'

WHITE = (0xFF, 0xFF, 0xFF)
SOFT = (0xFF, 0xD7, 0xDC)
FAINT = (0xFF, 0xFF, 0xFF, 0x18)


def background(w, h):
    """Diagonal-ish red ramp: brighter top-left, oxblood bottom-right."""
    img = Image.new('RGB', (w, h))
    px = img.load()
    for y in range(h):
        for x in range(0, w, 4):
            t = (x / w * 0.55 + y / h * 0.45)
            c = tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM))
            for dx in range(4):
                if x + dx < w:
                    px[x + dx, y] = c
    return img


def main():
    w, h = W * SS, H * SS
    img = background(w, h).convert('RGBA')
    d = ImageDraw.Draw(img)

    # Faint command text, top-right, on its own layer so the alpha actually
    # blends (ImageDraw.text replaces pixels rather than compositing), and
    # faded out at the right edge so nothing looks cut off.
    mono = ImageFont.truetype(MONO, round(20 * SS))
    layer = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    lines = [
        'systemctl enable --now httpd',
        'semanage fcontext -a -t httpd_t',
        'lvextend -r -L +2G /dev/vg0/data',
        'firewall-cmd --add-service=http',
    ]
    y = round(34 * SS)
    for line in lines:
        ld.text((round(560 * SS), y), line, font=mono, fill=(255, 255, 255, 255))
        y += round(38 * SS)

    fade = Image.new('L', (w, h), 0)
    fd = ImageDraw.Draw(fade)
    for x in range(round(540 * SS), w):
        t = (x - 540 * SS) / (w - 540 * SS)
        # ramp up off the left edge, then back down before the right edge
        a = min(t / 0.18, 1.0) * min((1 - t) / 0.30, 1.0)
        fd.line([(x, 0), (x, h)], fill=round(42 * max(a, 0)))
    layer.putalpha(Image.composite(layer.getchannel('A').point(lambda v: v),
                                   fade, layer.getchannel('A')).point(lambda v: v))
    layer = Image.merge('RGBA', (*layer.split()[:3],
                                 Image.eval(layer.getchannel('A'),
                                            lambda v: v)))
    # keep only where glyphs were drawn, at the faded strength
    alpha = Image.new('L', (w, h), 0)
    glyph_mask = layer.getchannel('A').point(lambda v: 255 if v > 0 else 0)
    alpha.paste(fade, mask=glyph_mask)
    layer.putalpha(alpha)
    img.alpha_composite(layer)

    # Icon glyph, left, on its own rounded tile so it reads as the app mark.
    tile = round(228 * SS)
    tx, ty = round(72 * SS), round((H - 228) / 2 * SS)
    d.rounded_rectangle([tx, ty, tx + tile, ty + tile],
                        radius=round(52 * SS), fill=(0x6E, 0x02, 0x0E, 0xB0))
    img.alpha_composite(glyph(tile, 0.50), dest=(tx, ty))

    # Wordmark and supporting copy.
    text_x = round(352 * SS)
    title = ImageFont.truetype(BOLD, round(72 * SS))
    sub = ImageFont.truetype(REG, round(30 * SS))
    tag = ImageFont.truetype(REG, round(23 * SS))

    d.text((text_x, round(196 * SS)), 'RHCSA Quiz', font=title, fill=WHITE)
    d.text((text_x, round(284 * SS)),
           'Offline practice for the exam objectives', font=sub, fill=SOFT)
    d.text((text_x, round(330 * SS)),
           '478 questions  \u00b7  22 chapters  \u00b7  No ads, no account',
           font=tag, fill=(0xFF, 0xEE, 0xF0))

    out = img.convert('RGB').resize((W, H), Image.LANCZOS)
    root = os.path.join(os.path.dirname(__file__), '..')
    path = os.path.join(root, 'store/feature_graphic_1024x500.png')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out.save(path)
    print('wrote', path)


if __name__ == '__main__':
    main()
