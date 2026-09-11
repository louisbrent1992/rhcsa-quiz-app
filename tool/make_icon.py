#!/usr/bin/env python3
"""Generate the app icon source images.

Draws a shell prompt chevron and a block cursor on the app's red — the
thing an RHCSA candidate stares at all day. Geometric rather than typeset,
so the mark stays crisp when a launcher shrinks it to 48px, and deliberately
avoids anything resembling Red Hat's trademarked logo.

Outputs:
  icon/icon.png            1024x1024 full-bleed, source for Android/iOS/Linux
  icon/foreground.png      1024x1024 transparent, glyph in the adaptive safe zone
  icon/icon_rounded.png    1024x1024 preview with a launcher's corner radius
  store/play_icon_512.png  512x512 flattened, for the Play Store listing

Run:  python3 tool/make_icon.py
"""
import os

from PIL import Image, ImageDraw

S = 1024
SS = 4  # supersample factor; everything is drawn 4x then downscaled

TOP = (0xE8, 0x11, 0x23)      # brighter red, top of the gradient
BOTTOM = (0x8C, 0x03, 0x12)   # deep oxblood, bottom
INK = (0xFF, 0xFF, 0xFF)      # chevron
CURSOR = (0xFF, 0xD7, 0xDC)   # warmer, so it reads as a separate cursor block

# Share of the canvas the glyph group spans on the full-bleed icon.
FULL_BLEED_SPAN = 0.44
# Adaptive foregrounds are masked hard; keep the glyph well inside the
# guaranteed-visible circle. ic_launcher.xml already insets by 16%.
ADAPTIVE_SPAN = 0.36


def gradient(size):
    """Vertical TOP -> BOTTOM ramp."""
    img = Image.new('RGB', (1, size))
    px = img.load()
    for y in range(size):
        t = y / (size - 1)
        px[0, y] = tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM))
    return img.resize((size, size), Image.BICUBIC)


def glyph(canvas, span):
    """Draw the prompt group centred on a transparent `canvas`-sized layer.

    `span` is the fraction of the canvas the group should occupy horizontally.
    """
    layer = Image.new('RGBA', (canvas, canvas), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    group_w = canvas * span
    # Proportions of the group: chevron, gap, cursor.
    chev_w = group_w * 0.46
    gap = group_w * 0.18
    cur_w = group_w * 0.26
    height = group_w * 0.92
    stroke = group_w * 0.145

    left = (canvas - group_w) / 2
    # Optical centring: the chevron's mass sits left of its bounding box.
    top = (canvas - height) / 2

    # Chevron: two strokes meeting at the right-hand point, round joins.
    apex = (left + chev_w, top + height / 2)
    d.line([(left, top), apex], fill=INK, width=round(stroke), joint='curve')
    d.line([apex, (left, top + height)], fill=INK, width=round(stroke),
           joint='curve')
    for pt in ((left, top), apex, (left, top + height)):
        r = stroke / 2
        d.ellipse([pt[0] - r, pt[1] - r, pt[0] + r, pt[1] + r], fill=INK)

    # Cursor block, bottom-aligned with the chevron, slightly shorter.
    cur_h = height * 0.88
    cx0 = left + chev_w + gap
    cy1 = top + height
    cy0 = cy1 - cur_h
    d.rounded_rectangle([cx0, cy0, cx0 + cur_w, cy1],
                        radius=stroke * 0.22, fill=CURSOR)
    return layer


def rounded_mask(size, radius_frac=0.2237):
    """iOS/launcher-style corner radius, as a mask."""
    m = Image.new('L', (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle(
        [0, 0, size - 1, size - 1], radius=size * radius_frac, fill=255)
    return m


def main():
    big = S * SS
    root = os.path.join(os.path.dirname(__file__), '..')

    # Full-bleed square icon.
    base = gradient(big).convert('RGBA')
    base.alpha_composite(glyph(big, FULL_BLEED_SPAN))
    icon = base.resize((S, S), Image.LANCZOS)
    icon.convert('RGB').save(os.path.join(root, 'icon/icon.png'))

    # Adaptive foreground: glyph only, transparent field, smaller safe span.
    fg = glyph(big, ADAPTIVE_SPAN).resize((S, S), Image.LANCZOS)
    fg.save(os.path.join(root, 'icon/foreground.png'))

    # Rounded preview.
    rounded = icon.copy()
    rounded.putalpha(rounded_mask(S))
    rounded.save(os.path.join(root, 'icon/icon_rounded.png'))

    # Play Store listing icon: 512x512, no alpha (Play rejects transparency).
    store_dir = os.path.join(root, 'store')
    os.makedirs(store_dir, exist_ok=True)
    icon.convert('RGB').resize((512, 512), Image.LANCZOS).save(
        os.path.join(store_dir, 'play_icon_512.png'))

    print('wrote icon/icon.png, icon/foreground.png, icon/icon_rounded.png, '
          'store/play_icon_512.png')


if __name__ == '__main__':
    main()
