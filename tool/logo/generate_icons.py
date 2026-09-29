"""Generate every launcher icon and web icon from one source of truth.

Run:  python tool/logo/generate_icons.py

Why a generator instead of committed PNGs only: adaptive icons need the glyph at
several different insets, a maskable icon needs the artwork pulled *inside* the
72% safe zone, and the web PWA needs separate maskable variants. Hand-maintaining
that matrix is exactly how an icon ends up with the handset clipped by the
launcher's circular mask. The PNGs are committed; this script is what regenerates
them.

Outputs
-------
android/app/src/main/res/mipmap-*/ic_launcher.png          legacy square icon
android/app/src/main/res/mipmap-*/ic_launcher_foreground.png adaptive foreground
android/app/src/main/res/drawable/ic_launcher_foreground.xml   vector foreground
android/app/src/main/res/mipmap-*/ic_launcher_round.png     legacy round icon
android/app/src/main/res/values/ic_launcher_background.xml    adaptive background
android/app/src/main/res/drawable*/launch_background.xml      splash (dark)
web/favicon.png, web/icons/Icon-{192,512}.png
web/icons/Icon-maskable-{192,512}.png
"""

from __future__ import annotations

import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)

from refine_logo import render, render_monochrome  # noqa: E402  (sibling module)

RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
WEB = os.path.join(ROOT, "web")

# Launcher densities -> square icon edge in px.
DENSITIES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}

# Adaptive icons are 108dp. Only the middle 72dp (66.6%) is guaranteed visible
# after the launcher applies a circle/squircle mask, so the glyph is sized to sit
# inside that. Artwork outside the safe zone is cropped away on some devices.
ADAPTIVE_ARTWORK = 0.52

# Web manifest icons.
WEB_ICON = 192
WEB_MASKABLE = 512


def _write(img: Image.Image, path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, "PNG", optimize=True)
    print("  ", os.path.relpath(path, ROOT).replace("\\", "/"))


def legacy_icons() -> None:
    """Pre-Oreo square/circle PNGs. These are shown unmasked, so the artwork
    may fill the tile; the rounded square is baked into the pixels."""
    for density, px in DENSITIES.items():
        outdir = os.path.join(RES, f"mipmap-{density}")
        _write(render(px), os.path.join(outdir, "ic_launcher.png"))
        _write(render(px, circular=True),
               os.path.join(outdir, "ic_launcher_round.png"))

        # Adaptive foregrounds: transparent canvas, artwork at safe-zone scale.
        # 108/72 = 1.5, so the artwork is drawn on a 1.5x canvas then the glyph
        # is scaled to the safe zone.
        fpx = int(px * 1.5)
        fg = render(fpx, scale=ADAPTIVE_ARTWORK)
        _write(fg, os.path.join(outdir, "ic_launcher_foreground.png"))

        # Themed-icon layer: silhouette on transparency, tinted by the OS.
        _write(render_monochrome(fpx, scale=ADAPTIVE_ARTWORK),
               os.path.join(outdir, "ic_launcher_monochrome.png"))


def adaptive_background() -> None:
    """Flat blue behind the glyph so the masked icon never shows transparency."""
    path = os.path.join(RES, "values", "ic_launcher_background.xml")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            "<resources>\n"
            '    <color name="ic_launcher_background">#2563EB</color>\n'
            "</resources>\n"
        )
    print("  ", os.path.relpath(path, ROOT).replace("\\", "/"))


def web_icons() -> None:
    _write(render(WEB_ICON), os.path.join(WEB, "icons", f"Icon-{WEB_ICON}.png"))
    _write(render(WEB_MASKABLE),
           os.path.join(WEB, "icons", f"Icon-{WEB_MASKABLE}.png"))

    # Maskable icons must survive a *circular* crop of the full canvas, so the
    # artwork is shrunk well inside the 80% safe zone and the background runs to
    # the edges (bleed=True, no pre-rounded corners). A gradient over the whole
    # canvas is what makes the round crop look intentional rather than clipped.
    for px in (192, 512):
        canvas = render(px, scale=0.34, bleed=True)
        _write(canvas, os.path.join(WEB, "icons", f"Icon-maskable-{px}.png"))

    # favicon: keep the flat dark background so it stays visible on light tabs
    _write(render(32), os.path.join(WEB, "favicon.png"))


def main() -> None:
    print("legacy + adaptive launcher icons")
    legacy_icons()
    print("adaptive background")
    adaptive_background()
    print("web icons")
    web_icons()
    print("done")


if __name__ == "__main__":
    main()
