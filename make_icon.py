#!/usr/bin/env python3
"""Generate a 1024x1024 app icon that matches the in-app header glyph.

The popover header in main.swift uses the SF Symbol "moon.stars.fill" drawn
in white on the green accent strip. We recreate the same visual here for the
macOS app icon so the Dock / Finder / Launchpad icon and the in-app glyph
agree: white crescent moon with two small 5-pointed stars, on a rounded
green background.
"""
from PIL import Image, ImageDraw
import math
import os

SIZE = 1024
# Exactly the "green" accent light-mode pair from kAccentPalette in main.swift
# — RGB(0.086, 0.396, 0.204) in 0..1 space = (22, 101, 52) in 0..255.
BG  = (22, 101, 52, 255)
FG  = (255, 255, 255, 255)

img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# macOS big-sur / liquid-glass icon shape — rounded square.
RADIUS = 220
draw.rounded_rectangle((0, 0, SIZE - 1, SIZE - 1), radius=RADIUS, fill=BG)


# ---------------------------------------------------------------- crescent
# Crescent = big white disc minus a slightly smaller offset green disc.
# Proportions roughly match SF Symbol "moon.stars.fill" at this canvas size:
# the moon sits centered-left, with the bite taken out of its upper-right
# so the two stars nestle inside the bite and to the upper-right.
moon_cx, moon_cy, moon_r = 470, 545, 285
draw.ellipse(
    (moon_cx - moon_r, moon_cy - moon_r, moon_cx + moon_r, moon_cy + moon_r),
    fill=FG,
)
cut_cx, cut_cy, cut_r = moon_cx + 155, moon_cy - 75, 270
draw.ellipse(
    (cut_cx - cut_r, cut_cy - cut_r, cut_cx + cut_r, cut_cy + cut_r),
    fill=BG,
)


# ---------------------------------------------------------------- stars
def star(cx, cy, r_out, r_in, n=5, rot=-math.pi / 2):
    """Return the points of an n-pointed star centered at (cx, cy)."""
    pts = []
    for i in range(2 * n):
        r = r_out if i % 2 == 0 else r_in
        a = rot + i * math.pi / n
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


# Big star above the crescent's opening — the dominant accent of the glyph.
draw.polygon(star(780, 360, 105, 48), fill=FG)
# Smaller star further up-right, tucked into the corner of the icon.
draw.polygon(star(870, 620, 62, 28), fill=FG)

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "icon.png")
img.save(out, "PNG")
print(f"Wrote {out}")
