#!/usr/bin/env python3
"""compare_guide.py - mean absolute RGB difference between a Godot screenshot and the style guide (plan 8.3, addendum P07 amendment 4).

Needs only Pillow and numpy (the project venv: tools/art/.venv/bin/python; run it with -I). No browser is needed at test time:
the seven Playwright renders of the guide at 1280x720 are committed in tests/checkpoints/guide_ref/pw1x_<screen>.png.

Screens: title select hud shop quest inventory forest   (guide: Titel, Vaelg figur, Gaard HUD, Butik, Opgavebog, Inventar, Moerkeskoven HUD)

  compare_guide.py SHOT [SHOT ...]
        SHOT is  <screen>=<file.png>  or a file whose NAME STARTS WITH the screen (hud.png, hud_noon.png, forest_boss.png).
        Reference = guide_ref/pw1x_<screen>.png.
  compare_guide.py --ref REF.png SHOT.png [--no-frame-crop] [--region x,y,w,h]
        compare against ANY reference picture (a Godot-rendered mock of the feature screens, F7/F8): one SHOT only.

Method (the UI spike's, so the numbers stay comparable): the reference loses the 2 px ink frame the HTML screen box has
(1280x720 -> 1276x716; `--no-frame-crop` keeps the reference whole, for Godot-rendered references that have no frame), the shot is
resized (Lanczos) to the reference's size, then mean(|ref - shot|) over all RGB values (0-255) and the share of pixels whose largest
channel difference exceeds 40.
  --region x,y,w,h   compare only this rectangle; x y w h are pixels of the COMPARISON SPACE (the reference after the optional frame
                     crop: 1276x716 for the bundled references, 1280x720 with --no-frame-crop)
  --frame-px N       frame width to crop (default 2): an integer >= 0 that leaves a picture (2 x N < the shorter side of the
                     reference); anything else is a usage error (exit 2) naming the limit
  --out PREFIX       also write PREFIX_<screen>_side.png (reference | shot) and PREFIX_<screen>_diff.png (difference x3)
  --json             print one JSON document instead of text lines
  --max N            exit 1 when any screen's mean difference is above N
  --target S=N       per-screen limit (repeatable), e.g. --target hud=9 --target forest=15
Exit codes: 0 ok, 1 a limit was exceeded, 2 usage / file error (a missing, unreadable, corrupt or truncated picture, a malformed
--target / --max / --region value): 1 is reserved for "the picture is too far from the guide", so a caller (F7, F8, P27) can tell a
failed diff target from a broken input.
"""
import argparse
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageChops

HERE = os.path.dirname(os.path.abspath(__file__))
REF_DIR = os.path.join(HERE, "guide_ref")
SCREENS = ["title", "select", "hud", "shop", "quest", "inventory", "forest"]


def bundled_ref(screen):
    return os.path.join(REF_DIR, "pw1x_%s.png" % screen)


def parse_region(text):
    try:
        parts = [int(p) for p in text.split(",")]
    except ValueError:
        parts = []
    if len(parts) != 4 or parts[2] <= 0 or parts[3] <= 0 or parts[0] < 0 or parts[1] < 0:
        raise ValueError("--region wants x,y,w,h as non-negative pixels with w,h > 0 (got %r)" % text)
    return tuple(parts)


def split_shot(arg):
    """'hud=a.png' -> ('hud', 'a.png'); 'forest_boss.png' -> ('forest', 'forest_boss.png'); None screen when it cannot be told."""
    if "=" in arg and arg.split("=", 1)[0] in SCREENS:
        name, path = arg.split("=", 1)
        return name, path
    stem = os.path.splitext(os.path.basename(arg))[0]
    for s in SCREENS:
        if stem == s or stem.startswith(s + "_") or stem.startswith("pw1x_" + s):
            return s, arg
    return None, arg


def load_rgb(path):
    """The picture as RGB. Raises ValueError (with the file name) for anything that is not a readable picture: a text file, a
    corrupt or truncated PNG, a decompression bomb. PIL signals those with OSError, SyntaxError or its own error classes."""
    try:
        with Image.open(path) as im:
            return im.convert("RGB")
    except (OSError, SyntaxError, ValueError, Image.DecompressionBombError) as e:
        raise ValueError("cannot read %s as a picture (%s: %s)" % (path, type(e).__name__, e)) from None


def parse_limit(text, what):
    """A finite number >= 0 from the command line, else ValueError."""
    try:
        v = float(text)
    except (TypeError, ValueError):
        raise ValueError("%s wants a number (got %r)" % (what, text)) from None
    if math.isnan(v) or v < 0:
        raise ValueError("%s wants a number >= 0 (got %r)" % (what, text))
    return v


def check_frame_px(frame_px, size=None):
    """Validates --frame-px: an integer >= 0 and, once the reference size is known (`size` = (width, height)), small enough to
    leave a picture (2 x N < the shorter side). Raises ValueError with the limit in the message. PIL's crop() would otherwise
    accept a negative value (a PADDED picture and a wrong number) or fail with 'Coordinate right is less than left'."""
    if isinstance(frame_px, bool) or not isinstance(frame_px, int) or frame_px < 0:
        raise ValueError("--frame-px wants a whole number >= 0 (got %r)" % (frame_px,))
    if size is not None:
        limit = (min(size) - 1) // 2
        if frame_px > limit:
            raise ValueError("--frame-px %d leaves nothing of the %dx%d reference: use 0 to %d" % (frame_px, size[0], size[1], limit))
    return frame_px


def compare(ref_path, shot_path, frame_crop=True, frame_px=2, region=None):
    """-> dict(mean, over40_pct, size, ref_img, shot_img) of one pair; raises ValueError on a bad region or --frame-px."""
    check_frame_px(frame_px)
    ref = load_rgb(ref_path)
    shot = load_rgb(shot_path)
    if frame_crop:
        check_frame_px(frame_px, ref.size)
        ref = ref.crop((frame_px, frame_px, ref.width - frame_px, ref.height - frame_px))
    if shot.size != ref.size:
        shot = shot.resize(ref.size, Image.Resampling.LANCZOS)
    if region is not None:
        x, y, w, h = region
        if x + w > ref.width or y + h > ref.height:
            raise ValueError("--region %s lies outside the comparison space %dx%d" % (",".join(map(str, region)), ref.width, ref.height))
        box = (x, y, x + w, y + h)
        ref = ref.crop(box)
        shot = shot.crop(box)
    diff = np.asarray(ImageChops.difference(ref, shot)).astype(np.float64)
    return {
        "mean": float(diff.mean()),
        "over40_pct": float((diff.max(axis=2) > 40).mean() * 100.0),
        "size": [ref.width, ref.height],
        "ref_img": ref,
        "shot_img": shot,
        "diff": diff,
    }


def write_artifacts(prefix, screen, res):
    ref, shot, diff = res["ref_img"], res["shot_img"], res["diff"]
    w, h = ref.size
    sheet = Image.new("RGB", (w * 2 + 12, h), (60, 60, 60))
    sheet.paste(ref, (0, 0))
    sheet.paste(shot, (w + 12, 0))
    sheet.save("%s_%s_side.png" % (prefix, screen))
    Image.fromarray(np.clip(diff * 3, 0, 255).astype("uint8")).save("%s_%s_diff.png" % (prefix, screen))


def main(argv=None):
    ap = argparse.ArgumentParser(description="Mean absolute RGB difference of screenshots against the style guide renders.", add_help=True)
    ap.add_argument("shots", nargs="+", help="<screen>=<png> or a png whose name starts with the screen name")
    ap.add_argument("--ref", help="compare against this reference picture instead of guide_ref/pw1x_<screen>.png (one shot only)")
    ap.add_argument("--no-frame-crop", action="store_true", help="do not crop the 2 px HTML frame from the reference (Godot-rendered references)")
    ap.add_argument("--frame-px", type=int, default=2, help="width of the frame to crop (default 2)")
    ap.add_argument("--region", help="x,y,w,h in pixels of the comparison space")
    ap.add_argument("--out", help="write PREFIX_<screen>_side.png and PREFIX_<screen>_diff.png")
    ap.add_argument("--json", action="store_true", help="print a JSON document")
    ap.add_argument("--max", type=float, help="fail when a mean difference is above this")
    ap.add_argument("--target", action="append", default=[], help="per-screen limit screen=N (repeatable)")
    a = ap.parse_args(argv)

    try:
        region = parse_region(a.region) if a.region else None
        check_frame_px(a.frame_px)
    except ValueError as e:
        print("compare_guide: %s" % e, file=sys.stderr)
        return 2
    targets = {}
    for t in a.target:
        if "=" not in t or t.split("=", 1)[0] not in SCREENS:
            print("compare_guide: --target wants screen=N with screen in %s (got %r)" % (",".join(SCREENS), t), file=sys.stderr)
            return 2
        try:
            targets[t.split("=", 1)[0]] = parse_limit(t.split("=", 1)[1], "--target %s" % t.split("=", 1)[0])
        except ValueError as e:
            print("compare_guide: %s" % e, file=sys.stderr)
            return 2
    if a.max is not None and (math.isnan(a.max) or a.max < 0):
        print("compare_guide: --max wants a number >= 0 (got %r)" % a.max, file=sys.stderr)
        return 2
    if a.ref and len(a.shots) != 1:
        print("compare_guide: --ref takes exactly one SHOT", file=sys.stderr)
        return 2

    results = {}
    exit_code = 0
    for arg in a.shots:
        screen, path = split_shot(arg)
        if a.ref:
            screen = screen or os.path.splitext(os.path.basename(path))[0]
            ref_path = a.ref
        else:
            if screen is None:
                print("compare_guide: cannot tell the screen of %r (use <screen>=<png>; screens: %s)" % (arg, ", ".join(SCREENS)), file=sys.stderr)
                return 2
            ref_path = bundled_ref(screen)
        for p in (ref_path, path):
            if not os.path.isfile(p):
                print("compare_guide: no such file: %s" % p, file=sys.stderr)
                return 2
        try:
            res = compare(ref_path, path, not a.no_frame_crop, a.frame_px, region)
        except ValueError as e:
            print("compare_guide: %s" % e, file=sys.stderr)
            return 2
        results[screen] = {"mean": round(res["mean"], 3), "over40_pct": round(res["over40_pct"], 3), "size": res["size"], "ref": ref_path, "shot": path}
        limit = targets.get(screen, a.max)
        if limit is not None and res["mean"] > limit:
            results[screen]["limit"] = limit
            results[screen]["exceeded"] = True
            exit_code = 1
        if a.out:
            try:
                write_artifacts(a.out, screen, res)
            except OSError as e:
                print("compare_guide: cannot write the --out pictures (%s)" % e, file=sys.stderr)
                return 2
    if a.json:
        print(json.dumps({"screens": results, "region": list(region) if region else None, "frame_crop": not a.no_frame_crop}, indent=2, sort_keys=True))
    else:
        for screen, r in results.items():
            extra = "   EXCEEDS limit %.2f" % r["limit"] if r.get("exceeded") else ""
            print("%-10s mean abs diff (0-255): %6.2f   pixels with diff>40: %5.2f%%   (%dx%d)%s" % (screen, r["mean"], r["over40_pct"], r["size"][0], r["size"][1], extra))
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
