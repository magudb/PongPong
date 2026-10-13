"""Rebuilds assets/fonts/TTSymbols-Regular.ttf from NotoSansSymbols2-Regular.ttf (needs: pip install fonttools).
Why: Godot sizes a text line by the TALLEST font in a FontVariation fallback chain, and Noto Symbols 2 has 1.7 em
line metrics, which made every Caprasimo button 40% too tall. The subset keeps only the glyphs the UI uses
(▸ ◂ ♥ ★ ✓ ✗ ...) and its hhea/OS2 vertical metrics are set to 0.90/-0.25 em."""
import sys
from fontTools.ttLib import TTFont
from fontTools import subset
# usage: make_symbols_font.py [--src PATH-TO-NotoSansSymbols2-Regular.ttf]   (the 1.2 MB Noto binary is NOT shipped: TTSymbols already covers every glyph)
src = sys.argv[sys.argv.index("--src") + 1] if "--src" in sys.argv else "assets/fonts/NotoSansSymbols2-Regular.ttf"
opts = subset.Options(); opts.layout_features = ["*"]; opts.name_IDs = ["*"]; opts.notdef_outline = True
f = TTFont(src)
uni = [0x25B8, 0x25C2, 0x25B6, 0x25C0, 0x25BE, 0x25B4, 0x2665, 0x2661, 0x2605, 0x2606, 0x2713, 0x2714, 0x2717, 0x2718, 0x2726, 0x2022, 0x2715, 0x2716, 0x2736, 0x2727]
sub = subset.Subsetter(opts); sub.populate(unicodes=[u for u in uni if u in f.getBestCmap()]); sub.subset(f)
# the guide's "▸" is a bold caret ~ the x-height of Caprasimo; Noto's is small, so scale the arrow glyphs 1.7x
cmap = f.getBestCmap(); glyf = f["glyf"]; hmtx = f["hmtx"]
for cp in (0x25B8, 0x25C2, 0x25B6, 0x25C0):
    if cp not in cmap:
        continue
    gn = cmap[cp]; g = glyf[gn]
    if g.numberOfContours <= 0:
        continue
    coords = g.coordinates
    xs = [c[0] for c in coords]; ys = [c[1] for c in coords]
    cx = (min(xs) + max(xs)) / 2; cy = (min(ys) + max(ys)) / 2
    k = 1.7
    for i, (x, y) in enumerate(coords):
        coords[i] = (int(cx + (x - cx) * k), int(cy + (y - cy) * k))
    g.recalcBounds(glyf)
    adv, lsb = hmtx[gn]
    hmtx[gn] = (int(adv * k), int(g.xMin))
upm = f["head"].unitsPerEm; asc = int(0.90 * upm); desc = -int(0.25 * upm)
f["hhea"].ascent = asc; f["hhea"].descent = desc; f["hhea"].lineGap = 0
o = f["OS/2"]; o.sTypoAscender = asc; o.sTypoDescender = desc; o.sTypoLineGap = 0; o.usWinAscent = asc; o.usWinDescent = -desc
for rec in f["name"].names:
    if rec.nameID in (1, 4, 16): rec.string = "Traetoppen Symbols"
    if rec.nameID in (3, 6): rec.string = "TraetoppenSymbols-Regular"
f.save("assets/fonts/TTSymbols-Regular.ttf")
