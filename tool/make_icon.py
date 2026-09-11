#!/usr/bin/env python3
"""Generate the app icon source images.

Draws a root shell prompt ("#" plus a block cursor) on the app's red — the
mark a RHCSA candidate stares at all day. Deliberately avoids anything
resembling Red Hat's trademarked logo.

Outputs, all 1024x1024:
  icon/icon.png            full-bleed square, source for Android/iOS/Linux
  icon/foreground.png      transparent, glyph inside the adaptive-icon safe zone
  icon/icon_rounded.png    preview with the corner radius a launcher applies

Run:  python3 tool/make_icon.py
"""
from PIL import Image, ImageDraw, ImageFont

S = 1024
TOP = (0xE8, 0x11, 0x23)      # brighter red, top of the gradient
BOTTOM = (0x8C, 0x03, 0x12)   # deep oxblood, bottom
INK = (0xFF, 0xFF, 0xFF)
CURSOR = (0xFF, 0xE3, 0xE6)   # very slightly warm, so it reads as a cursor

FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf'

# Share of the adaptive icon's guaranteed-visible area the glyph should fill.
TARGET_VISIBLE = 0.58
# What ic_launcher.xml leaves after its 16% inset.
ADAPTIVE_DRAWABLE = 0.68


def gradient(size: int) -> Image.Image:
    """Vertical gradient; drawn once per row rather than per pixel."""
    img = Image.new('RGB', (1, size))
    px = img.load()
    for y in range(size):
        t = y / (size - 1)
        px[0, y] = tuple(round(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3))
    return img.resize((size, size), Image.BILINEAR)


def draw_glyph(img: Image.Image, scale: float) -> None:
    """Draw '#' plus a block cursor, centred, sized as a fraction of the canvas.

    `scale` is the cap height of the glyph relative to the canvas, letting the
    adaptive foreground sit smaller inside its safe zone.
    """
    d = ImageDraw.Draw(img)
    size = round(S * scale)
    font = ImageFont.truetype(FONT, size)

    hash_box = d.textbbox((0, 0), '#', font=font)
    hw = hash_box[2] - hash_box[0]
    hh = hash_box[3] - hash_box[1]

    # Block cursor, proportioned like a real terminal caret: narrow, square
    # cornered, and just shy of the glyph's cap height.
    cw = round(hw * 0.34)
    ch = round(hh * 0.95)
    gap = round(hw * 0.28)

    total = hw + gap + cw
    x0 = (S - total) / 2
    cy = S / 2

    d.text((x0 - hash_box[0], cy - hh / 2 - hash_box[1]), '#', font=font, fill=INK)

    cx = x0 + hw + gap
    d.rectangle([cx, cy - ch / 2, cx + cw, cy + ch / 2], fill=CURSOR)


def fit_to_width(glyph: Image.Image, target_frac: float) -> Image.Image:
    """Centre `glyph`'s inked content on a transparent square canvas, scaled so
    that content spans `target_frac` of the canvas width.

    Measuring the drawn result beats reasoning about font metrics: the '#'
    advance width, its bearings and the cursor block all contribute, and the
    only number that matters is how much ink ends up on screen.
    """
    box = glyph.getbbox()
    content = glyph.crop(box)
    target_w = round(S * target_frac)
    scale = target_w / content.width
    resized = content.resize(
        (target_w, max(1, round(content.height * scale))), Image.LANCZOS
    )
    out = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    out.paste(resized, ((S - resized.width) // 2, (S - resized.height) // 2))
    return out


def rounded(img: Image.Image, radius_frac: float) -> Image.Image:
    mask = Image.new('L', (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, S - 1, S - 1], radius=round(S * radius_frac), fill=255
    )
    out = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    out.paste(img.convert('RGBA'), (0, 0), mask)
    return out


def main() -> None:
    # Full-bleed square. Launchers apply their own mask, so no rounding here.
    icon = gradient(S)
    draw_glyph(icon, 0.44)
    icon.save('icon/icon.png')

    # Adaptive foreground. Android composites this on a 108dp canvas of which
    # only the centre 72dp (66.7%) is guaranteed visible, and ic_launcher.xml
    # insets the drawable a further 16%. Content spanning fraction f of this
    # image ends up spanning f * 0.68 / (72/108) of the visible area, so working
    # back:  f = 0.58 * (72/108) / 0.68 = 0.569 of this image's width.
    drawn = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_glyph(drawn, 0.44)
    fg = fit_to_width(drawn, TARGET_VISIBLE * (72 / 108) / ADAPTIVE_DRAWABLE)
    fg.save('icon/foreground.png')

    rounded(icon, 0.22).save('icon/icon_rounded.png')
    print('wrote icon/icon.png, icon/foreground.png, icon/icon_rounded.png')


if __name__ == '__main__':
    main()
