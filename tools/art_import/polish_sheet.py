"""Polish pass for Daemon sprite sheets: reduce each sheet to ~15 colors of its own.

AI-generated sheets come out with thousands of near-identical colors. This picks a small palette
from the sheet's own pixels and snaps every pixel to it, using the Aseprite MCP's tools (which run
Aseprite in batch mode):

  1. palette: k-means over the sheet's opaque colors, each color weighted by the square root of its
     pixel count, so small accents (effect cyan, LED green, pure white) still win a slot instead of
     being swallowed by big body areas; each center is then snapped to the nearest real sheet color
  2. MCP `set_palette` + `quantize_to_palette` (Aseprite snaps every pixel), then `export_sprite`

Run with the Aseprite MCP's Python environment (it has Pillow and the MCP package):

    cd /path/to/aseprite-mcp
    uv run python /path/to/Pokemon_Style_Game/tools/art_import/polish_sheet.py <sheet.png> [<sheet.png> ...]
        [--out-dir DIR] [--colors 15]

Writes the polished PNG next to the input (or into --out-dir) and prints colors before/after.
"""
import argparse
import asyncio
import json
import os
import shutil
import subprocess
import tempfile

from PIL import Image

from aseprite_mcp.tools.analysis import get_color_stats
from aseprite_mcp.tools.export import export_sprite
from aseprite_mcp.tools.palette import quantize_to_palette, set_palette

KMEANS_ROUNDS = 25


def _hex(c):
    return "#%02X%02X%02X" % c[:3]


def _rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def _dist(a, b):
    return sum((x - y) ** 2 for x, y in zip(a, b)) ** 0.5


def opaque_colors(png_path):
    """{(r, g, b): pixel count} for pixels at least half opaque."""
    img = Image.open(png_path).convert("RGBA")
    counts = {}
    for r, g, b, a in img.getdata():
        if a >= 128:
            counts[(r, g, b)] = counts.get((r, g, b), 0) + 1
    return counts


def pick_palette(counts, k):
    """Weighted k-means (weight = sqrt(pixel count)), centers snapped to real sheet colors."""
    items = [(c, n ** 0.5) for c, n in counts.items()]
    if len(items) <= k:
        return [c for c, _ in items]
    # k-means++ style seeding: start with the heaviest color, then add the one furthest away (weighted).
    centers = [max(items, key=lambda it: it[1])[0]]
    while len(centers) < k:
        best = max(items, key=lambda it: it[1] * min(_dist(it[0], c) for c in centers) ** 2)
        centers.append(best[0])
    centers = [tuple(float(v) for v in c) for c in centers]
    for _ in range(KMEANS_ROUNDS):
        sums = [[0.0, 0.0, 0.0, 0.0] for _ in centers]
        for c, w in items:
            i = min(range(len(centers)), key=lambda j: _dist(c, centers[j]))
            s = sums[i]
            s[0] += c[0] * w; s[1] += c[1] * w; s[2] += c[2] * w; s[3] += w
        moved = [(s[0] / s[3], s[1] / s[3], s[2] / s[3]) if s[3] > 0 else centers[i] for i, s in enumerate(sums)]
        if all(_dist(a, b) < 0.5 for a, b in zip(moved, centers)):
            break
        centers = moved
    # Snap each center to the most-used real color near it, so the palette only has colors the art had.
    palette = []
    for ctr in centers:
        near = sorted(items, key=lambda it: _dist(it[0], ctr))[:12]
        pick = max(near, key=lambda it: it[1])[0]
        if pick not in palette:
            palette.append(pick)
    return palette


async def polish(png_path, out_path, colors, aseprite):
    work = tempfile.mkdtemp(prefix="polish_")
    try:
        ase = os.path.join(work, "sheet.aseprite")
        subprocess.run([aseprite, "-b", png_path, "--save-as", ase], check=True, capture_output=True)
        before = json.loads(await get_color_stats(ase, 1, 1))["unique_colors"]
        palette = [_hex(c) for c in pick_palette(opaque_colors(png_path), colors)]
        await set_palette(ase, palette)
        await quantize_to_palette(ase)
        after = json.loads(await get_color_stats(ase, 1, 1))["unique_colors"]
        result = await export_sprite(ase, out_path)
        if "success" not in result.lower():
            raise RuntimeError(result)
        return before, after, palette
    finally:
        shutil.rmtree(work, ignore_errors=True)


async def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("sheets", nargs="+")
    ap.add_argument("--out-dir")
    ap.add_argument("--colors", type=int, default=15)
    args = ap.parse_args()
    aseprite = os.getenv("ASEPRITE_PATH", "aseprite")
    for sheet in args.sheets:
        out = os.path.join(args.out_dir, os.path.basename(sheet)) if args.out_dir else sheet
        before, after, palette = await polish(sheet, out, args.colors, aseprite)
        print(f"{os.path.basename(sheet)}: {before} -> {after} colors {' '.join(palette)}")


if __name__ == "__main__":
    asyncio.run(main())
