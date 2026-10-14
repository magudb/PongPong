#!/usr/bin/env python3
"""The glide hook of the ghost must not touch any other character (work order task 3; section check art_ghost.hook_leaves_other_characters_byte_identical).

  tools/art/.venv/bin/python -I tools/art/ghost/check_hook.py [--json] [--keep] [--shim-dir DIR]

Builds the GLB of the fox, the bat and the fairy (the three rigs the hook could reach: the only ones with legs + arms + tail / wings) in THREE import
configurations of the generator, each in its own process (the module `traetoppen_additions` is cached after the first import):

  bare    tools/art/generator only                                          -> no extra module at all (TT_BUILDERS / EXTRA_CLIPS empty)
  p21     generator + tools/art/characters (P21's traetoppen_additions)       -> the state of every normal produce_all.sh run
  shim    tools/art/ghost FIRST + generator + characters                      -> the state of produce_ghost.sh (the shim hides P21's module)

and compares the sha256 of the three GLBs across the configurations: they must be EQUAL (the base generator, the pack and P21's characters stay
byte-identical).  The ghost's own GLB is built in `shim` and in `shim_nohook` (the same shim with EXTRA_CLIPS emptied): THOSE must DIFFER, otherwise
the hook would be a dead no-op and the equality above would prove nothing (teeth).  Exit 0 = all good, 1 = a hash differs / the hook is dead.

--shim-dir DIR checks another copy of ghost_model.py + traetoppen_additions.py (probe_gates.sh feeds it a mutant whose hook leaks and expects exit 1).

Measured when the hook was designed (design4/notes/glide_hook_is_ghost_only.txt): fox f3b254a5.., bat 015c1bf9.., fairy ff43bd98.. in two independent runs.
The numbers depend on the installed numpy / scipy, so they are printed, and the equality ACROSS configurations is the gate (not the absolute hash).
"""
import argparse, hashlib, json, os, shutil, subprocess, sys
from pathlib import Path

sys.dont_write_bytecode = True        # no __pycache__ in the generator / core folders of other packages
HERE = Path(__file__).resolve().parent
ART = HERE.parent
RECORDED = {'fox': 'f3b254a5', 'bat': '015c1bf9', 'fairy': 'ff43bd98'}      # info only: sha256 prefixes of the design4 measurement
OTHERS = ['fox', 'bat', 'fairy']
CONFIGS = ['bare', 'p21', 'shim', 'shim_nohook']


def config_path(config: str, shim_dir: Path):
    return {'bare': [ART / 'generator'], 'p21': [ART / 'generator', ART / 'characters'],
            'shim': [shim_dir, ART / 'generator', ART / 'characters'], 'shim_nohook': [shim_dir, ART / 'generator', ART / 'characters']}[config]


def child(config: str, out: Path, shim_dir: Path) -> None:
    """Runs in its own process: builds the GLBs of this configuration into `out` and prints {id: sha256} as JSON."""
    sys.path[:0] = [str(p) for p in config_path(config, shim_dir)]
    sys.dont_write_bytecode = True
    import build_assets as b                      # noqa: E402  (the generator: imports traetoppen_additions from the first folder that has one)
    if config == 'shim_nohook':
        b.EXTRA_CLIPS.clear()                     # the same shim with the glide hooks taken away again
    out.mkdir(parents=True, exist_ok=True)
    ids = list(OTHERS) + (['ghost_bu'] if config.startswith('shim') else [])
    res = {}
    for cid in ids:
        maker = b.TT_BUILDERS.get(cid) or b.BUILDERS.get(cid, getattr(b.geo, 'make_' + cid, None))   # = build_assets.main()
        if maker is None:
            raise SystemExit(f'{config}: no builder for {cid}')
        b.export(maker(), out)
        res[cid] = hashlib.sha256((out / f'{cid}.glb').read_bytes()).hexdigest()
    res['_hooks'] = sorted(b.EXTRA_CLIPS)
    res['_extra_builders'] = sorted(b.TT_BUILDERS)
    print('RESULT ' + json.dumps(res))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split('Measured when')[0], formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--child', help=argparse.SUPPRESS)
    ap.add_argument('--out', help=argparse.SUPPRESS)
    ap.add_argument('--shim-dir', default=str(HERE), help='folder with the ghost_model.py + traetoppen_additions.py to check (default: this folder)')
    ap.add_argument('--json', action='store_true', help='print the result as one JSON line')
    ap.add_argument('--keep', action='store_true', help='keep the GLBs (default: delete them)')
    a = ap.parse_args()
    shim_dir = Path(a.shim_dir).resolve()
    if a.child:
        child(a.child, Path(a.out), shim_dir)
        return 0
    sys.path.insert(0, str(ART / 'core'))
    import artpaths                                # noqa: E402
    work = artpaths.stage_root() / 'ghost_hook_check'
    artpaths.assert_stage_dir(work, 'hook check folder')
    if work.exists():
        shutil.rmtree(work)
    results = {}
    for config in CONFIGS:
        cp = subprocess.run([sys.executable, '-I', str(Path(__file__).resolve()), '--child', config, '--out', str(work / config), '--shim-dir', str(shim_dir)],
                            capture_output=True, text=True, env={**os.environ, 'PYTHONDONTWRITEBYTECODE': '1'})
        line = next((l for l in cp.stdout.splitlines() if l.startswith('RESULT ')), None)
        if cp.returncode != 0 or line is None:
            print(f'FAIL {config}: exit {cp.returncode}\n{cp.stdout[-800:]}\n{cp.stderr[-1500:]}')
            return 1
        results[config] = json.loads(line[7:])
    if not a.keep:
        shutil.rmtree(work, ignore_errors=True)
    problems = []
    for cid in OTHERS:
        hashes = {c: results[c][cid] for c in CONFIGS}
        if len(set(hashes.values())) != 1:
            problems.append(f'{cid}: GLB differs between configurations {hashes}')
    ghost_hook, ghost_nohook = results['shim']['ghost_bu'], results['shim_nohook']['ghost_bu']
    if ghost_hook == ghost_nohook:
        problems.append('ghost_bu: the GLB with the glide hooks equals the one without them (the hook is dead, the identity check above has no teeth)')
    if results['shim']['_hooks'] != ['run', 'walk'] or results['shim']['_extra_builders'] != ['ghost_bu', 'ghost_hviske']:
        problems.append(f'shim exposes hooks {results["shim"]["_hooks"]} / builders {results["shim"]["_extra_builders"]} (want run, walk / ghost_bu, ghost_hviske)')
    if a.json:
        print(json.dumps({'results': results, 'problems': problems}))
    else:
        for cid in OTHERS:
            h = results['shim'][cid]
            note = ' (= the design4 measurement)' if h.startswith(RECORDED[cid]) else f' (design4 measured {RECORDED[cid]}.., other numpy build)'
            print(f'{cid:6s} sha256 {h[:16]}.. identical in bare / p21 / shim{note}' if cid not in ' '.join(problems) else f'{cid:6s} DIFFERS')
        print(f'ghost_bu GLB with the glide hooks {ghost_hook[:16]}.. differs from the one without {ghost_nohook[:16]}.. (the hook is alive)')
    print('check_hook: ' + ('OK - the hook is ghost-only: fox, bat, fairy are byte-identical with and without the shim' if not problems else 'FAILED\n  ' + '\n  '.join(problems)))
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
