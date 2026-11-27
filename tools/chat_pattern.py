"""Makes the chat background tiles (assets/chat/) from tools/chat_pattern/source.jpeg.

The source is a doodle wallpaper (light lines on a dark background) that
doesn't repeat by itself. This cuts out every doodle and scatters them on a
square tile that wraps around at the edges, so copies of the tile join without
a seam (like WhatsApp's chat background). It writes the lines only, on a
transparent background, once per theme:

    assets/chat/pattern-light.png  (+ @2x)   dark lines, for the light theme
    assets/chat/pattern-dark.png   (+ @2x)   light lines, for the dark theme

The app draws them faintly over the chat's background (Theme.chatPattern*).
Needs Pillow, numpy and scipy. Usage: python tools/chat_pattern.py [--seed N]
"""
import argparse
import random
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "tools" / "chat_pattern" / "source.jpeg"
OUT = ROOT / "assets" / "chat"

TILE = 800          # tile size in source pixels (= the @2x file)
GAP = 6             # free space around each doodle, in source pixels
MAX_COPIES = 2      # how often one doodle may appear in a tile
COLORS = {"light": (0x19, 0x1C, 0x1A), "dark": (0xEB, 0xEF, 0xED)}  # Theme.text


def line_alpha(gray):
    """Lines as 0..1 coverage: brightness above the (vignetted) background."""
    background = ndi.median_filter(gray, size=31)
    signal = np.clip(gray - background, 0, None)
    alpha = np.clip((signal - 5) / 10, 0, 1)
    # drop the paper texture: specks that aren't part of a stroke
    labels, n = ndi.label(alpha > 0.3)
    sizes = ndi.sum(np.ones_like(alpha), labels, index=np.arange(1, n + 1))
    keep = np.isin(labels, np.flatnonzero(sizes >= 25) + 1)
    keep = ndi.binary_dilation(keep, iterations=2)
    return alpha * keep


def doodles(alpha):
    """(alpha crop, footprint crop) for each doodle fully inside the image."""
    grouped = ndi.binary_dilation(alpha > 0.3, iterations=10)
    labels, _ = ndi.label(grouped)
    out = []
    h, w = alpha.shape
    for index, box in enumerate(ndi.find_objects(labels), start=1):
        ys, xs = box
        if ys.start == 0 or xs.start == 0 or ys.stop == h or xs.stop == w:
            continue    # cut by the image edge
        if max(ys.stop - ys.start, xs.stop - xs.start) < 60:
            continue    # a stray piece of a doodle, not a whole one
        own = np.pad(labels[box] == index, GAP)
        crop = np.pad(alpha[box], GAP) * own
        footprint = ndi.binary_dilation(own, iterations=GAP)
        out.append((crop, footprint))
    return out


def scatter(items, rng):
    tile = np.zeros((TILE, TILE))
    taken = np.zeros((TILE, TILE), bool)
    uses = [0] * len(items)
    order = list(range(len(items)))
    misses = 0
    while misses < 400:
        rng.shuffle(order)
        placed_any = False
        for i in order:
            if uses[i] >= MAX_COPIES:
                continue
            crop, footprint = items[i]
            hh, ww = crop.shape
            for _ in range(60):
                y, x = rng.randrange(TILE), rng.randrange(TILE)
                rows = (np.arange(hh) + y) % TILE
                cols = (np.arange(ww) + x) % TILE
                if (taken[np.ix_(rows, cols)] & footprint).any():
                    continue
                taken[np.ix_(rows, cols)] |= footprint
                region = tile[np.ix_(rows, cols)]
                tile[np.ix_(rows, cols)] = np.maximum(region, crop)
                uses[i] += 1
                placed_any = True
                break
            else:
                misses += 1
        if not placed_any:
            break
    return tile, sum(uses)


def save(alpha, color, path):
    rgba = np.zeros(alpha.shape + (4,), np.uint8)
    rgba[..., :3] = color
    rgba[..., 3] = np.round(alpha * 255)
    Image.fromarray(rgba).save(path, optimize=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--seed", type=int, default=7)
    args = parser.parse_args()

    gray = np.asarray(Image.open(SOURCE).convert("L")).astype(float)
    items = doodles(line_alpha(gray))
    tile, count = scatter(items, random.Random(args.seed))
    print(f"{len(items)} doodles in the source, {count} placed on a {TILE}px tile")

    OUT.mkdir(parents=True, exist_ok=True)
    half = np.asarray(Image.fromarray(np.round(tile * 255).astype(np.uint8))
                      .resize((TILE // 2, TILE // 2), Image.LANCZOS)).astype(float) / 255
    for theme, color in COLORS.items():
        save(tile, color, OUT / f"pattern-{theme}@2x.png")
        save(half, color, OUT / f"pattern-{theme}.png")


if __name__ == "__main__":
    main()
