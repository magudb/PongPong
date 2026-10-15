#!/usr/bin/env python3
"""Checks of the shim (tools/art/cast_v2/traetoppen_additions.py) for tests/sections/art_cast_v2.gd; prints one `PASS <id> <detail>` or `FAIL <id> <detail>`
line per check (the format of every PASS/FAIL tool of the harness) and exits 1 when any failed.

  builders_resolve           with tools/art/cast_v2 FIRST on PYTHONPATH the generator (build_assets.TT_BUILDERS) resolves the six new ids and the two restyled ids to the
                             builders of cast_v2_models, keeps every other P21 builder as it was, and re-exports EXTRA_PATTERNS / EXTRA_CLIPS unchanged; without the folder
                             on the path the six ids do not exist (the P21 look of the two restyled ids is what the generator builds); all eight models build with the
                             slug, clip set and palette the work order names
  shim_does_not_edit_p21     tools/art/characters/traetoppen_additions.py is byte-identical before and after importing the shim and building the eight models, the table P21
                             exports is not mutated (36 builders, the two restyled ids still P21's functions), and no file of this folder writes under tools/art/characters
  no_new_pattern_no_new_clip EXTRA_PATTERNS / EXTRA_CLIPS of the shim are the very objects of P21's module (no new texture pattern, no new clip)
  palette_table_is_the_design  palettes_v2.json carries the 13 figures of design section 3.4 and every builder reads its hex from it (the models' colours contain the table)

Run: tools/art/.venv/bin/python -I tools/art/cast_v2/check_shim.py        (-I: the folder of the script is not put on the path implicitly)
"""
import hashlib
import importlib
import json
import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ART = HERE.parent
REPO = ART.parents[1]
P21_FILE = ART / 'characters' / 'traetoppen_additions.py'
os.environ.setdefault('PYTHONDONTWRITEBYTECODE', '1')
sys.path[:0] = [str(HERE), str(ART / 'generator'), str(ART / 'core')]

NEW_IDS = ['bear_brumme', 'bat_natteblik', 'hedgehog_pip', 'owl_fru_ugle', 'capybara_sofus', 'fairy_birk_npc']
RESTYLE_IDS = ['fairy_shopkeeper', 'cat_morfar_mis']
CLIP_SET = {'bear_brumme': 'villager', 'bat_natteblik': 'npc_flyer', 'hedgehog_pip': 'villager', 'owl_fru_ugle': 'villager', 'capybara_sofus': 'villager',
            'fairy_birk_npc': 'npc_flyer', 'fairy_shopkeeper': 'npc_flyer', 'cat_morfar_mis': 'villager'}
FIGURE_OF = {'bear_brumme': 'brumme', 'bat_natteblik': 'natteblik', 'hedgehog_pip': 'pip', 'owl_fru_ugle': 'fru_ugle', 'capybara_sofus': 'sofus',
             'fairy_birk_npc': 'birk', 'fairy_shopkeeper': 'kloevermynte', 'cat_morfar_mis': 'morfar_mis'}
results = []


def report(name, ok, detail=''):
    results.append((name, ok))
    print('%s %s %s' % ('PASS' if ok else 'FAIL', name, detail))


def sha(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main() -> int:
    before = sha(P21_FILE)
    import build_assets as ba
    import cast_v2_models as cv2
    import traetoppen_additions as shim
    p21 = cv2.p21()
    p21_ids = list(p21.BUILDERS)

    # ---- builders_resolve
    problems = []
    for cid in NEW_IDS + RESTYLE_IDS:
        fn = ba.TT_BUILDERS.get(cid)
        if fn is None:
            problems.append('%s missing in TT_BUILDERS' % cid)
        elif fn.__module__ != 'cast_v2_models':
            problems.append('%s resolves to %s (the shim did not win the import)' % (cid, fn.__module__))
    for cid in p21_ids:
        if cid in RESTYLE_IDS:
            continue
        if ba.TT_BUILDERS.get(cid) is not p21.BUILDERS[cid]:
            problems.append('P21 builder %s changed' % cid)
    if len(ba.TT_BUILDERS) != len(p21_ids) + len(NEW_IDS):
        problems.append('%d builders, want %d (P21 %d + 6 new)' % (len(ba.TT_BUILDERS), len(p21_ids) + len(NEW_IDS), len(p21_ids)))
    if ba.EXTRA_PATTERNS is not p21.EXTRA_PATTERNS or ba.EXTRA_CLIPS is not p21.EXTRA_CLIPS:
        problems.append('EXTRA_PATTERNS / EXTRA_CLIPS are not re-exported as they are')
    models = {}
    for cid in NEW_IDS + RESTYLE_IDS:
        try:
            m = ba.TT_BUILDERS[cid]()
        except Exception as e:                      # noqa: BLE001 - a builder that raises is a FAIL line, not a traceback
            problems.append('%s does not build: %s: %s' % (cid, type(e).__name__, e))
            continue
        models[cid] = m
        if m.slug != cid:
            problems.append('%s slug is %s' % (cid, m.slug))
        if m.clip_set != CLIP_SET[cid]:
            problems.append('%s clip set %s want %s' % (cid, m.clip_set, CLIP_SET[cid]))
        if getattr(m, 'cam_scale', None):
            problems.append('%s sets cam_scale (display_scale would not be 1.0)' % cid)
    # without the shim the generator knows only P21's table: run a clean interpreter whose path has NO cast_v2
    code = ("import sys, os\nsys.path[:0] = [%r, %r, %r]\nimport build_assets as b\nprint(sorted(set(%r) & set(b.TT_BUILDERS)))\n"
            "print(b.TT_BUILDERS['fairy_shopkeeper'].__module__)") % (str(ART / 'generator'), str(ART / 'core'), str(ART / 'characters'), NEW_IDS)
    out = subprocess.run([sys.executable, '-I', '-c', code], capture_output=True, text=True, env={**os.environ, 'PYTHONPATH': ''})
    lines = out.stdout.strip().splitlines()
    if out.returncode != 0 or len(lines) != 2 or lines[0] != '[]' or lines[1] != 'traetoppen_additions':
        problems.append('without the shim the generator should know none of the six ids and build P21\'s fairy_shopkeeper: %s %s' % (out.stdout.strip(), out.stderr.strip()[-200:]))
    report('builders_resolve', not problems and len(models) == 8,
           '8 ids -> cast_v2_models (6 new, 2 restyled in place), %d P21 builders untouched, slug / clip set as ordered; %s' % (len(p21_ids) - len(RESTYLE_IDS), '; '.join(problems[:4])))

    # ---- no_new_pattern_no_new_clip
    report('no_new_pattern_no_new_clip', shim.EXTRA_PATTERNS is p21.EXTRA_PATTERNS and shim.EXTRA_CLIPS is p21.EXTRA_CLIPS and set(shim.EXTRA_CLIPS) == {'attack', 'spin'},
           'EXTRA_PATTERNS %d, EXTRA_CLIPS %s: P21\'s own objects' % (len(shim.EXTRA_PATTERNS), sorted(shim.EXTRA_CLIPS)))

    # ---- shim_does_not_edit_p21
    after = sha(P21_FILE)
    probs = []
    if before != after:
        probs.append('P21 file changed during the run')
    if len(p21.BUILDERS) != 36:
        probs.append('P21 table has %d builders, want 36 (the shim mutated it?)' % len(p21.BUILDERS))
    for cid in RESTYLE_IDS:
        if p21.BUILDERS[cid].__module__ != cv2.P21_MODULE_NAME:
            probs.append('P21 table entry %s is not P21\'s function any more' % cid)
    writers = []
    for f in [x for x in sorted(HERE.glob('*.py')) + sorted(HERE.glob('*.sh')) if x.name != 'check_shim.py']:     # (this checker names the words it looks for)
        text = f.read_text(encoding='utf-8')
        for line in text.splitlines():
            s = line.strip()
            if s.startswith('#') or s.startswith('"""'):
                continue
            if ("art/characters" in s or "/ 'characters'" in s) and any(w in s for w in ('write_text', 'write_bytes', '.unlink', 'rmtree', "'w')", '"w")', 'shutil.copy', 'os.remove', 'os.rename')):
                writers.append('%s: %s' % (f.name, s[:90]))
    if writers:
        probs.append('writes under tools/art/characters: %s' % writers[:2])
    report('shim_does_not_edit_p21', not probs, 'tools/art/characters/traetoppen_additions.py sha256 %s.. before = after, table of 36 builders not mutated, no writer under tools/art/characters; %s' % (before[:10], '; '.join(probs)))

    # ---- palette_table_is_the_design
    table = json.loads((HERE / 'palettes_v2.json').read_text())['figures']
    want_figs = {'hoppe', 'brumme', 'morfar_mis', 'natteblik', 'rasmus', 'bertil', 'bodil', 'kloevermynte', 'birk', 'pip', 'fru_ugle', 'sofus', 'kiki'}
    probs = []
    if set(table) != want_figs:
        probs.append('figures %s' % sorted(set(table) ^ want_figs))
    for cid, m in models.items():
        colours = {sh.color.upper() for g in m.groups for sh in g.shapes}
        for region, v in table[FIGURE_OF[cid]].items():
            for hx in (v if isinstance(v, list) else [v]):
                if hx.upper() not in colours:
                    probs.append('%s.%s %s is not a colour of the baked model' % (cid, region, hx))
    report('palette_table_is_the_design', not probs, '13 figures of design 3.4; the models of the eight ids contain every region hex of their figure; %s' % '; '.join(probs[:3]))
    return 0 if all(ok for _, ok in results) else 1


if __name__ == '__main__':
    sys.exit(main())
