import sys, json
from pathlib import Path
import homepaths   # usage: sheet_scaffold.py <folder with home.json + PNG masters> OUT.png <tier> ...  (house N-1 with scaffold_toN over it)
from PIL import Image
root = Path(sys.argv[1]); out = sys.argv[2]; steps = [int(x) for x in sys.argv[3:]]
meta = json.loads((root / 'home.json').read_text())
ims = []
for t in steps:
    h = Image.open(root / meta['tiers'][str(t - 1)]['file']).convert('RGBA'); hp = meta['tiers'][str(t - 1)]['pivot']
    s = Image.open(root / meta['scaffold'][str(t)]['file']).convert('RGBA'); sp = meta['scaffold'][str(t)]['pivot']
    up = max(hp[1], sp[1]) + 20; dn = max(h.height - hp[1], s.height - sp[1]) + 20; lt = max(hp[0], sp[0]) + 20; rt = max(h.width - hp[0], s.width - sp[0]) + 20
    c = Image.new('RGBA', (lt + rt, up + dn), (169, 211, 160, 255))
    c.alpha_composite(h, (lt - hp[0], up - hp[1])); c.alpha_composite(s, (lt - sp[0], up - sp[1])); ims.append(c)
W = sum(i.width for i in ims); H = max(i.height for i in ims)
sheet = Image.new('RGB', (W, H), (169, 211, 160)); x = 0
for i in ims: sheet.paste(i.convert('RGB'), (x, H - i.height)); x += i.width
sheet.save(out); print(sheet.size)
