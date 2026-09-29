"""Refine the chosen logo: candidate B (gradient squircle + white handset).

Design notes, recorded so the choices are not re-litigated later:

* **Squircle, not circle.** Android applies its own mask to adaptive icons, and
  MIUI/HyperOS home screens display a circular or rounded-square icon as-is. A
  gradient needs a *shape* to read as a brand mark; a plain circle is
  indistinguishable from an avatar.
* **Gradient over flat.** The app is used in the dark (it is an incoming call at
  2am), but a near-black icon on a dark home screen is invisible. The blue
  gradient is the one treatment that stays legible on both wallpapers.
* **Handset, not bell.** The `ring_volume` bell (E/F) breaks up at 48px into an
  unrecognisable arc. The handset keeps a closed, readable silhouette.
* **No text, no phone numbers, no "incoming" wording.** An icon is the one asset
  visible on the lock screen / home screen even before the app opens, so it has
  to obey the same no-reveal rule as the UI.
"""

from __future__ import annotations

import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FONT = r"C:\flutterSDK\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf"
GLYPH_CALL = "\ue126"

SS = 8
BG_TOP = (59, 130, 246)   # AppColors.primaryGradient.begin  #3B82F6
BG_BOT = (30, 64, 175)    # deepened past #2563EB so the glyph keeps contrast
WHITE = (255, 255, 255)


def vgradient(w: int, h: int, top, bot) -> Image.Image:
    strip = Image.new("RGB", (1, h))
    px = strip.load()
    for y in range(h):
        t = y / max(h - 1, 1)
        px[0, y] = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))
    return strip.resize((w, h), Image.BILINEAR)


def squircle_mask(size: int, ratio: float) -> Image.Image:
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle(
        (0, 0, size - 1, size - 1), radius=int(size * ratio), fill=255
    )
    return m


def top_sheen(size: int) -> Image.Image:
    """A soft off-centre highlight so the tile reads as a physical object.

    Kept deliberately faint (peak alpha 30/255). An earlier pass used 90 and the
    top of the tile went pale enough to eat into the white handset's contrast —
    the glyph has to stay the brightest thing on the icon.
    """
    sheen = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(sheen)
    d.ellipse((-size * 0.25, -size * 0.95, size * 0.95, size * 0.30), fill=30)
    sheen = sheen.filter(ImageFilter.GaussianBlur(size / 11))
    return sheen


def glyph_mask(size: int, ch: str, scale: float) -> Image.Image:
    """Render `ch` so its *inked* bounding box is centred on the canvas.

    Centring on the font's declared metrics (textbbox) is wrong here: the
    `call` glyph is a 45-degree handset, so its em box and its visible ink do
    not share a centre. That left the mark ~2% high in the themed-icon layer.
    Rendering to a scratch layer and centring on getbbox() measures the pixels
    that actually ship.
    """
    scratch = Image.new("L", (size * 2, size * 2), 0)
    font = ImageFont.truetype(FONT, int(size * scale))
    ImageDraw.Draw(scratch).text((size // 2, size // 2), ch, font=font, fill=255)

    bbox = scratch.getbbox()
    if bbox is None:
        raise ValueError(f"glyph {ch!r} rendered empty")
    w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]

    out = Image.new("L", (size, size), 0)
    out.paste(scratch.crop(bbox), ((size - w) // 2, (size - h) // 2))
    return out


def render(size: int, *, radius_ratio: float = 0.2237, scale: float = 0.50,
           circular: bool = False, bleed: bool = False) -> Image.Image:
    """Render the mark at `size` px square.

    `bleed=True` drops the corner radius so the artwork runs to all four edges —
    required for PWA maskable icons, where the *platform* applies the mask and
    any pre-rounded corners show up as a second, wrong-shaped border.
    """
    s = size * SS
    base = vgradient(s, s, BG_TOP, BG_BOT).convert("RGBA")

    # sheen
    sheen = top_sheen(s)
    white_layer = Image.new("RGBA", (s, s), WHITE + (0,))
    white_layer.putalpha(sheen)
    base = Image.alpha_composite(base, white_layer)

    # handset
    glyph_layer = Image.new("RGBA", (s, s), WHITE + (255,))
    glyph_layer.putalpha(glyph_mask(s, GLYPH_CALL, scale))
    base = Image.alpha_composite(base, glyph_layer)

    if bleed:
        base.putalpha(255)
    elif circular:
        shape = Image.new("L", (s, s), 0)
        ImageDraw.Draw(shape).ellipse((0, 0, s - 1, s - 1), fill=255)
        base.putalpha(shape)
    else:
        base.putalpha(squircle_mask(s, radius_ratio))
    return base.resize((size, size), Image.LANCZOS)


def render_monochrome(size: int, scale: float = 0.52) -> Image.Image:
    """Silhouette-only tile for the themed-icon layer (API 33+).

    Android 13+ tints this layer to match the user's wallpaper palette, so it
    must be a single opaque shape on a *transparent* background. Reusing the
    gradient foreground here would tint the whole square blue, which is how a
    themed icon ends up as a solid blue block.
    """
    s = size * SS
    layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    solid = Image.new("RGBA", (s, s), (255, 255, 255, 255))
    solid.putalpha(glyph_mask(s, GLYPH_CALL, scale))
    layer = Image.alpha_composite(layer, solid)
    return layer.resize((size, size), Image.LANCZOS)


if __name__ == "__main__":
    out = os.path.join(HERE, "out")
    os.makedirs(out, exist_ok=True)
    render(512).save(os.path.join(out, "refined_512.png"))
    render(512, circular=True).save(os.path.join(out, "refined_512_circular.png"))

    # scale ladder, to check the silhouette survives
    ladder = Image.new("RGB", (620, 190), (28, 28, 28))
    x = 20
    for px in (192, 144, 96, 72, 60, 48, 36):
        im = render(px)
        ladder.paste(im, (x, 20), im)
        x += px + 18
    ladder.save(os.path.join(out, "_scale_ladder.png"))
    print("wrote refined previews")
