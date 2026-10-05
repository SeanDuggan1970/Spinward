"""Compose the itch.io page images from a --promo capture.

    godot --path . --resolution 1920x1080 -- --promo=<shots>
    python tools/make_itch_images.py <shots> [out=build/itch]

(--promo-ship=<shots> re-shoots just the ship-view stills into the same folder.)

Writes cover.png (630x500, itch's cover size) and cover@2x.png, banner.png
(1920x480, for the page header), and 19 numbered 1920x1080 screenshots, with the
title lettered in the game's own font (Consolas) and amber.
"""
import os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

shots = sys.argv[1]
out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "build", "itch")
os.makedirs(out, exist_ok=True)

AMBER = (232, 160, 48)
TEXT = (214, 210, 200)
HAZARD = (216, 176, 42)
FONT_BOLD = "C:/Windows/Fonts/consolab.ttf"
FONT = "C:/Windows/Fonts/consola.ttf"


def shot(name):
    return Image.open(os.path.join(shots, name)).convert("RGB")


def crop_to(img, w, h, focus=(0.5, 0.5)):
    """Scale to cover w x h, then crop around `focus` (fractions of the image)."""
    scale = max(w / img.width, h / img.height)
    img = img.resize((int(img.width * scale + 0.5), int(img.height * scale + 0.5)), Image.LANCZOS)
    x = int(min(max(img.width * focus[0] - w / 2, 0), img.width - w))
    y = int(min(max(img.height * focus[1] - h / 2, 0), img.height - h))
    return img.crop((x, y, x + w, y + h))


def logo(img, cx, cy, size, sub=None, spacing=0.55):
    """'S P I N W A R D' in amber with a drop shadow and a hazard-stripe rule under it."""
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(FONT_BOLD, size)
    text = " ".join("SPINWARD")
    tw = d.textlength(text, font=f)
    x = cx - tw / 2
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.text((x + size * 0.05, cy + size * 0.05), text, font=f, fill=(0, 0, 0, 200))
    shadow = shadow.filter(ImageFilter.GaussianBlur(size * 0.06))
    img.paste(shadow, (0, 0), shadow)
    d = ImageDraw.Draw(img)
    d.text((x, cy), text, font=f, fill=AMBER)
    # The hazard rule: short slanted dashes, as on the title screen.
    y = cy + size * 1.18
    dash = size * 0.32
    n = int(tw / (dash * 1.6))
    for k in range(n):
        x0 = x + k * dash * 1.6
        d.polygon([(x0, y + size * 0.1), (x0 + dash * 0.25, y), (x0 + dash, y), (x0 + dash * 0.75, y + size * 0.1)], fill=HAZARD)
    if sub:
        fs = ImageFont.truetype(FONT, int(size * 0.3))
        sw = d.textlength(sub, font=fs)
        d.text((cx - sw / 2 + 2, y + size * 0.32 + 2), sub, font=fs, fill=(0, 0, 0))
        d.text((cx - sw / 2, y + size * 0.32), sub, font=fs, fill=TEXT)


def vignette(img, strength=0.55):
    """Darken towards the top so the lettering reads."""
    grad = Image.new("L", (1, img.height))
    for yy in range(img.height):
        grad.putpixel((0, yy), int(255 * strength * max(0.0, 1.0 - yy / (img.height * 0.55)) ** 1.5))
    grad = grad.resize(img.size)
    black = Image.new("RGB", img.size, (0, 0, 0))
    return Image.composite(black, img, grad)


# Cover: Saturn's rings, the planet's shadow across them, Titan and a ship.
cover = vignette(crop_to(shot("cine-saturn-35.png"), 1260, 1000, (0.55, 0.55)))
logo(cover, 630, 70, 112, "A trading life in our own backyard  ·  2061")
cover.save(os.path.join(out, "cover@2x.png"))
cover.resize((630, 500), Image.LANCZOS).save(os.path.join(out, "cover.png"))

# Banner: Saturn and its rings to the right, a ship crossing; the title on the left,
# over a band darkened towards the left edge.
banner = crop_to(shot("cine-saturn-70.png"), 1920, 480, (0.5, 0.62))
fade = Image.new("L", (banner.width, 1))
for xx in range(banner.width):
    fade.putpixel((xx, 0), int(200 * max(0.0, 1.0 - xx / (banner.width * 0.62)) ** 1.2))
banner = Image.composite(Image.new("RGB", banner.size, (0, 0, 0)), banner, fade.resize(banner.size))
logo(banner, 600, 130, 104, "Real orbits  ·  real ships  ·  a hopeful future")
banner.save(os.path.join(out, "banner.png"))

# Screenshots, in page order: what it looks like, then what you do. The ship view
# (in transit, the director's set-ups) is woven through.
picks = [
    ("cine-jovian-70.png", "jupiter-callisto"),
    ("ship-huygens_port-plume_watch-30-longlens.png", "ship-view-saturn-long-lens"),
    ("play-cockpit-tsiolkovsky_wheel.png", "docking-at-a-stanford-torus"),
    ("cine-enceladus-35.png", "enceladus-plumes"),
    ("ship-huygens_port-plume_watch-60-dolly.png", "ship-view-deep-freighter"),
    ("play-cockpit-kibo_ring.png", "kibo-ring-night-side"),
    ("ship-kibo_ring-halo_depot-0-plume.png", "ship-view-burn-over-earth"),
    ("cine-mars-70.png", "mars-and-the-pavonis-line"),
    ("ship-huygens_port-plume_watch-60-world.png", "ship-view-saturn"),
    ("play-ride-luna-line.png", "riding-the-luna-line"),
    ("play-chase-landauer_deep.png", "landauer-deep-iapetus"),
    ("ship-kibo_ring-halo_depot-0-station.png", "ship-view-leaving-kibo-ring"),
    ("cine-lunar-70.png", "under-the-selene-ring"),
    ("ship-huygens_port-plume_watch-30-flyby.png", "ship-view-fly-past"),
    ("play-map.png", "plotted-transfer"),
    ("play-station-projects.png", "projects-and-pitches"),
    ("play-station-spaceline.png", "the-spaceline-news"),
    ("cine-sail-35.png", "lightfoot-solar-sail"),
    ("controls.png", "controls"),
]
for old in os.listdir(out):
    if old[:2].isdigit() and old[2] == "-" and old.endswith(".png"):
        os.remove(os.path.join(out, old))
for i, (name, label) in enumerate(picks, 1):
    shot(name).save(os.path.join(out, "%02d-%s.png" % (i, label)))
print("wrote", out)
