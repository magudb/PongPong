#!/usr/bin/env python3
"""crop_guide_refs.py - pins the crops of the style guide render that have no 1280x720 screen reference (package P28, UI_NAVIGATION.md 4.8).

The guide's seven screens have a Playwright render each (tests/checkpoints/guide_ref/pw1x_*.png). Parts of the guide that are not a whole screen - the
dialogue box of section 03 - only exist inside the big render `docs/Trætoppen Style Guide Review/refs/style_guide_render.png` (1440 x 8990). This tool cuts
them out into tests/checkpoints/guide_ref_ui/ and pins them with SHA256SUMS.

  crop_guide_refs.py            write the crops and SHA256SUMS
  crop_guide_refs.py --check    regenerate in memory, compare with the committed files and with SHA256SUMS; exit 1 on any drift, 2 on a missing file

Run it with the project venv, isolated:  tools/art/.venv/bin/python -I tools/ui/crop_guide_refs.py
Needs only Pillow. The crops are PNG written without metadata, deterministically (compress_level 9, no ancillary chunks), so a regeneration is byte-identical.

dialogue_box.png = region (684, 1844, 680, 300) of the render: the dialogue panel's border box is 660 x 266 at (694, 1854); the crop keeps its 6 px rings and
the soft shadow (10 px of margin on every side). compare_guide.py uses it with `--ref ... --no-frame-crop --region 0,0,680,300` (fixture `dialogue_guide`).
"""
import hashlib
import io
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SOURCE = os.path.join(ROOT, "docs", "Trætoppen Style Guide Review", "refs", "style_guide_render.png")
OUT_DIR = os.path.join(ROOT, "tests", "checkpoints", "guide_ref_ui")
# name -> (x, y, width, height) in the pixels of the render
CROPS = {
    "dialogue_box.png": (684, 1844, 680, 300),
}


def render_png(img):
    """The PNG bytes of an RGB image, deterministic (no metadata, fixed compression)."""
    buf = io.BytesIO()
    img.convert("RGB").save(buf, format="PNG", compress_level=9, optimize=False)
    return buf.getvalue()


def crops():
    if not os.path.isfile(SOURCE):
        print("crop_guide_refs: the guide render is missing: %s" % SOURCE, file=sys.stderr)
        sys.exit(2)
    with Image.open(SOURCE) as im:
        im.load()
        for name, (x, y, w, h) in CROPS.items():
            if x < 0 or y < 0 or x + w > im.width or y + h > im.height:
                print("crop_guide_refs: %s lies outside the %dx%d render" % (name, im.width, im.height), file=sys.stderr)
                sys.exit(2)
            yield name, render_png(im.crop((x, y, x + w, y + h)))


def sums_text(files):
    return "".join("%s  %s\n" % (hashlib.sha256(data).hexdigest(), name) for name, data in sorted(files.items()))


def main(argv):
    check = "--check" in argv
    files = dict(crops())
    want_sums = sums_text(files)
    if not check:
        os.makedirs(OUT_DIR, exist_ok=True)
        for name, data in files.items():
            with open(os.path.join(OUT_DIR, name), "wb") as f:
                f.write(data)
        with open(os.path.join(OUT_DIR, "SHA256SUMS"), "w") as f:
            f.write(want_sums)
        open(os.path.join(OUT_DIR, ".gdignore"), "a").close()
        print("crop_guide_refs: wrote %d crop(s) and SHA256SUMS to %s" % (len(files), OUT_DIR))
        return 0
    problems = []
    for name, data in files.items():
        path = os.path.join(OUT_DIR, name)
        if not os.path.isfile(path):
            problems.append("%s is missing" % name)
        elif open(path, "rb").read() != data:
            problems.append("%s differs from a fresh crop of the render" % name)
    sums_path = os.path.join(OUT_DIR, "SHA256SUMS")
    if not os.path.isfile(sums_path):
        problems.append("SHA256SUMS is missing")
    elif open(sums_path).read() != want_sums:
        problems.append("SHA256SUMS does not match the fresh crops")
    for p in problems:
        print("crop_guide_refs: DRIFT: " + p)
    if problems:
        return 1
    print("crop_guide_refs: %d crop(s) identical to a fresh crop, SHA256SUMS matches" % len(files))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
