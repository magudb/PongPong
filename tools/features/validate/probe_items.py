"""Run with the art venv:  tools/art/.venv/bin/python -I probe_items.py tools/art/features/home  <stage>/data/furniture_art_spec.json
Builds EVERY catalogue item with A1's real template function and Style (the exact call the bake uses) and prints {id: [footprint, height, layer, n_glow, error]} as JSON."""
import json
import sys

sys.dont_write_bytecode = True           # a probe must leave no __pycache__ in A1's folders
sys.path.insert(0, str(__import__('pathlib').Path(sys.argv[1]) / 'isometric'))
import homepaths  # noqa: E402,F401
import furniture_traetoppen as ft  # noqa: E402

spec = json.load(open(sys.argv[2]))['items']
out = {}
for e in spec:
    try:
        sp = ft.TEMPLATES[e['template']](ft.Style(**e['style']), **e['kw'])
        out[e['id']] = [list(sp.fp), round(sp.height, 2), sp.layer, 1 if sp.glow else 0, None]
    except Exception as ex:  # noqa: BLE001
        out[e['id']] = [None, None, None, None, repr(ex)[:120]]
print(json.dumps(out))
