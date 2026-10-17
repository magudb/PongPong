#!/usr/bin/env python3
"""Install only the extended rooms/routines. --check compares every output byte.

Original core schedules remain hand-owned; this tool cannot overwrite them.
Uses the existing room grammar and approved modular art, with no image generation.
"""
from pathlib import Path
import argparse
import subprocess
import sys
import tempfile
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE))
import gen_lua as L
import model as M


def outputs():
    out = {}
    for npc, row in M.CITIZENS.items():
        if row['wave'] == 'ext':
            out[f'lua/routines/ext/{npc}.lua'] = L.header('routines',f'Daily routine of {npc}; town extended content')+'\nroutines = {\n'+L.routine_lua(npc)+'\n}\n'
    lines = [L.header('buildings','Ten extended town rooms: public meeting places and friend homes'),'buildings = {']
    for row in M.BUILDINGS.values():
        if row['wave'] == 'ext':
            lines += L.building_lua(row)
    out['lua/buildings/ext.lua'] = '\n'.join(lines+['}'])+'\n'
    generator = ROOT/'tools/towns/interiors/generate.py'
    with tempfile.TemporaryDirectory() as temporary:
        for flag, folder, dest, suffix in [('--out','rooms','data/interiors/ext','.json'),('--maps','maps','data/maps','.map')]:
            target = Path(temporary)/folder
            subprocess.run([sys.executable,'-B','-I',str(generator),flag,str(target),'--wave','ext'],check=True,stdout=subprocess.DEVNULL)
            for p in sorted(target.glob('*'+suffix)):
                out[f'{dest}/{p.name}'] = p.read_text()
    for path in list(out):
        if path.endswith(('.lua','.map')):
            out[path+'.import'] = '[remap]\n\nimporter="keep"\n'
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true')
    args = parser.parse_args()
    bad = []
    for path, text in outputs().items():
        target = ROOT/path
        if args.check:
            if not target.exists() or target.read_text() != text: bad.append(path)
        else:
            target.parent.mkdir(parents=True,exist_ok=True)
            target.write_text(text)
    if bad: print('Out of date: '+', '.join(bad)); return 1
    print('Extended town content matches its authoring sources' if args.check else 'Installed ten rooms and seven citizen routines')
    return 0

if __name__ == '__main__': raise SystemExit(main())
