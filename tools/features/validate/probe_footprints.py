"""Run with the art venv (numpy needed):  tools/art/.venv/bin/python -I probe_footprints.py tools/art/features/home  -> JSON {template|kwargs|tier: [fp, layer, interact]} on stdout.
Calls the REAL template functions of A1's home art tables (tools/art/features/home/characters/furniture_traetoppen.py, import paths set by A1's homepaths.py)
for every template x kwarg x tier and prints what the geometry says."""
import json
import sys

sys.dont_write_bytecode = True           # a probe must leave no __pycache__ in A1's folders
sys.path.insert(0, str(__import__('pathlib').Path(sys.argv[1]) / 'isometric'))
import homepaths  # noqa: E402,F401  (puts characters : isometric : generator : core in A1's contract order on sys.path)
import furniture_traetoppen as ft  # noqa: E402

VARIANTS = {'bed': [dict(size='double'), dict(size='single')], 'table': [dict(size='round'), dict(size='dining'), dict(size='long')],
            'sofa': [dict(seats=2), dict(seats=3)], 'wardrobe': [dict(size='wide'), dict(size='narrow')], 'bookshelf': [dict(size='wide'), dict(size='narrow')],
            'rug': [dict(shape='rect'), dict(shape='round'), dict(shape='runner')], 'painting': [dict(size='small'), dict(size='wide')]}
out = {}
for tpl, fn in ft.TEMPLATES.items():
    for kw in VARIANTS.get(tpl, [{}]):
        for tier in (0, 1, 2, 3, 4):
            sp = fn(ft.Style(tier=tier), **kw)
            out[f'{tpl}|{json.dumps(kw, sort_keys=True)}|{tier}'] = [list(sp.fp), sp.layer, (sp.interact or {}).get('type')]
print(json.dumps(out))
