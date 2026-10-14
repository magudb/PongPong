#!/usr/bin/env python3
"""contact_sheet.py - a labelled contact sheet of screenshots (art is judged on sheets, never on single frames).

usage: contact_sheet.py OUT.png IMG [IMG ...] [--cols N] [--width PX]
Every image is scaled to --width (default 640) pixels wide, laid out in --cols columns (default 2) with its file name above it.
"""
import os, sys
from PIL import Image, ImageDraw, ImageFont


def main(argv):
    cols, width, files = 2, 640, []
    i = 0
    while i < len(argv):
        if argv[i] == "--cols":
            cols = int(argv[i + 1]); i += 2
        elif argv[i] == "--width":
            width = int(argv[i + 1]); i += 2
        else:
            files.append(argv[i]); i += 1
    if len(files) < 2:
        print(__doc__)
        return 2
    out, imgs = files[0], files[1:]
    tiles = []
    for f in imgs:
        im = Image.open(f).convert("RGB")
        h = int(round(im.height * width / im.width))
        tiles.append((os.path.basename(f), im.resize((width, h), Image.LANCZOS)))
    label_h = 20
    rows = (len(tiles) + cols - 1) // cols
    row_h = [max(t[1].height for t in tiles[r * cols:(r + 1) * cols]) + label_h for r in range(rows)]
    sheet = Image.new("RGB", (cols * width + (cols + 1) * 6, sum(row_h) + (rows + 1) * 6), (30, 26, 44))
    d = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 12)
    except Exception:
        font = ImageFont.load_default()
    y = 6
    for r in range(rows):
        for c in range(cols):
            k = r * cols + c
            if k >= len(tiles):
                break
            x = 6 + c * (width + 6)
            d.text((x, y + 3), tiles[k][0], fill=(240, 230, 200), font=font)
            sheet.paste(tiles[k][1], (x, y + label_h))
        y += row_h[r] + 6
    sheet.save(out)
    print("wrote", out, sheet.size)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
