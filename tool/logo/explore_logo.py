"""Render logo candidates so the shape can be chosen before it is shipped.

This is a design tool, not part of the build. It writes to `out/` and is never
invoked by `flutter build`; the generated PNGs are committed instead.

Why Pillow + a font glyph rather than an SVG pipeline: the machine has no SVG
rasteriser (no rsvg-convert / inkscape / cairosvg), and an icon redrawn as
hand-tuned bezier paths would be a lot of fragile code for one glyph. The
Material Icons `call` glyph is the same geometry the app already draws on the
incoming-call screen, so the icon and the UI agree.
"""

from __future__ import annotations

import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")

FONT = r"C:\flutterSDK\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf"
# `call` is a classic handset curve. It reads unambiguously at launcher size,
# which a phone *outline* (the other obvious candidate) does not.
GLYPH_CALL = "\ue126"
GLYPH_RING = "\ue539"

BG = (11, 15, 20)  # AppColors.background
GRAD_TOP = (59, 130, 246)  # AppColors.primaryGradient start
GRAD_BOT = (37, 99, 235)  # AppColors.primaryGradient end
WHITE = (242, 246, 250)  # AppColors.textPrimary

SS = 8  # supersampling factor; everything is drawn huge then LANCZOS-downscaled


def gradient(size: int, top: tuple, bot: tuple) -> Image.Image:
    """Vertical linear gradient, built with numpy-free per-row drawing."""
    img = Image.new("RGB", (1, size))
    px = img.load()
    for y in range(size):
        t = y / max(size - 1, 1)
        px[0, y] = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))
    return img.resize((size, size), Image.BILINEAR)


def rounded(size: int, radius_ratio: float, fill) -> Image.Image:
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle(
        (0, 0, size - 1, size - 1), radius=int(size * radius_ratio), fill=fill
    )
    return layer


def glyph_mask(size: int, ch: str, scale: float) -> Image.Image:
    """Render `ch` centred, filling `scale` of the canvas."""
    img = Image.new("L", (size, size), 0)
    font = ImageFont.truetype(FONT, int(size * scale))
    d = ImageDraw.Draw(img)
    box = d.textbbox((0, 0), ch, font=font)
    w, h = box[2] - box[0], box[3] - box[1]
    d.text(
        ((size - w) / 2 - box[0], (size - h) / 2 - box[1]), ch, font=font, fill=255
    )
    return img


def candidate(name: str, *, bg_kind: str, glyph: str, scale: float,
              glyph_fill, radius_ratio: float) -> None:
    s = 512 * SS
    if bg_kind == "gradient":
        bg = gradient(s, GRAD_TOP, GRAD_BOT).convert("RGBA")
        canvas = rounded(s, radius_ratio, None)
        canvas.paste(bg, (0, 0), rounded(s, radius_ratio, (255, 255, 255, 255)))
    elif bg_kind == "dark":
        canvas = rounded(s, radius_ratio, BG + (255,))
    else:  # "circle"
        canvas = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        ImageDraw.Draw(canvas).ellipse((0, 0, s - 1, s - 1), fill=BG + (255,))

    canvas.paste(glyph_fill, (0, 0), glyph_mask(s, glyph, scale))
    out = canvas.resize((512, 512), Image.LANCZOS)
    path = os.path.join(OUT, f"{name}.png")
    out.save(path)
    print("wrote", os.path.relpath(path, HERE))


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    # A: dark squircle + white handset (best contrast on a dark home screen)
    candidate("a_dark_squircle_handset", bg_kind="dark", glyph=GLYPH_CALL,
              scale=0.46, glyph_fill=WHITE, radius_ratio=0.22)
    # B: blue gradient squircle + white handset (brand-forward, pops on light)
    candidate("b_gradient_squircle_handset", bg_kind="gradient", glyph=GLYPH_CALL,
              scale=0.46, glyph_fill=WHITE, radius_ratio=0.22)
    # C: dark circle + white handset (OEM mask-safe reference)
    candidate("c_dark_circle_handset", bg_kind="circle", glyph=GLYPH_CALL,
              scale=0.44, glyph_fill=WHITE, radius_ratio=0)
    # D: dark squircle + green handset (matches the answer action colour)
    candidate("d_dark_squircle_green", bg_kind="dark", glyph=GLYPH_CALL,
              scale=0.46, glyph_fill=(34, 197, 94), radius_ratio=0.22)
    # E: dark squircle + ringing-bell glyph
    candidate("e_dark_squircle_ring", bg_kind="dark", glyph=GLYPH_RING,
              scale=0.46, glyph_fill=WHITE, radius_ratio=0.22)
    # F: gradient squircle + ringing-bell glyph
    candidate("f_gradient_squircle_ring", bg_kind="gradient", glyph=GLYPH_RING,
              scale=0.46, glyph_fill=WHITE, radius_ratio=0.22)

    # Contact sheet so the candidates can be compared side by side, and a
    # 1:1 strip that shows them at true launcher size (48px) — the size that
    # actually decides whether a glyph survives.
    names = sorted(n[:1] for n in os.listdir(OUT) if n.endswith(".png"))
    cells = []
    for letter in "abcdef":
        p = os.path.join(OUT, f"{letter}_*.png")
        import glob

        g = glob.glob(p)
        if g:
            cells.append((letter, Image.open(g[0]).convert("RGBA")))

    sheet = Image.new("RGB", (len(cells) * 200 + 20, 200 + 120), (30, 30, 30))
    d = ImageDraw.Draw(sheet)
    for i, (letter, im) in enumerate(cells):
        x = 10 + i * 200
        sheet.paste(im.resize((180, 180), Image.LANCZOS), (x, 10), im.resize((180, 180), Image.LANCZOS))
        small = im.resize((48, 48), Image.LANCZOS)
        sheet.paste(small, (x + 66, 210), small)
        d.text((x + 66, 270), f"{letter} @48", fill=(200, 200, 200))
    sheet.save(os.path.join(OUT, "_contact_sheet.png"))
    print("wrote contact sheet")


if __name__ == "__main__":
    main()
