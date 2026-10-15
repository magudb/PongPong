#!/usr/bin/env python3
"""Self-test of add_autoload.py on COPIES of project.godot (never the real file).  Prints one `PASS <id>` / `FAIL <id>` line per check (tests/lib/t.gd expect_tool_ids reads them).

    python3 tools/features/test_add_autoload.py [--project FILE]

EVERY test root is built from the PRISTINE form of --project: the feature autoload lines of CONTRACT (HomeManager ... SocialManager) are stripped from the copy before any check runs, so the self-test
passes on the live project.godot whether none, some or all of the feature packages have already registered their line (fix round RT2: without this it failed as soon as ONE line existed, and every
wave-4 owner package adds one).  The file given is only read, never written.

Checks: add_all, second_run_is_noop, base_block_untouched, added_after_animal_husbandry, skips_missing_scripts, parallel_runs_do_not_corrupt, refuses_other_path, refuses_unknown_name,
refuses_foreign_entry, refuses_missing_section, refusal_leaves_file_unchanged, dry_run_writes_nothing, file_mode_kept.
Review F1 r2 (fix round 2): dedupes_repeated_names (a name given twice is added once, so the file never gets a duplicate line), refuses_duplicate_entry (a file that already has a feature autoload
twice is refused, never "repaired" and never reported as fine), refuses_missing_project / refuses_missing_project_creates_no_lock (a --project that does not exist exits 3 with a message, no traceback,
no stray lock file), refuses_missing_root, refuses_unreadable_project (not UTF-8 text: exit 3, untouched).
Fix round RT2 (the sixth autoload SocialManager): only_the_feature_lines_were_added (was only_the_five_lines_were_added), contract_names_match_self_test (NAMES here == CONTRACT of the tool, same order),
fresh_feature_nodes_cover_the_contract (tests/lib/features/fresh.gd FEATURE_NODES == the contract, same order), pristine_copy_ignores_existing_feature_lines (the self-test run against a project.godot that
ALREADY has every feature line passes too: strip + a nested run).
Every count is len(NAMES): widening the contract needs no edit of a literal here.
"""
import argparse
import importlib.util
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
TOOL = HERE / 'add_autoload.py'
REPO = HERE.parents[1]
NAMES = {'HomeManager': 'scripts/home/home_manager.gd', 'FurnitureManager': 'scripts/furniture/furniture_manager.gd', 'WardrobeManager': 'scripts/wardrobe/wardrobe_manager.gd',
         'LootService': 'scripts/loot/loot_service.gd', 'CollectionLog': 'scripts/collection/collection_log.gd', 'SocialManager': 'scripts/social/social_manager.gd'}
FRESH = REPO / 'tests' / 'lib' / 'features' / 'fresh.gd'
fails = 0


def check(cid, ok, detail=''):
    global fails
    print(('PASS ' if ok else 'FAIL ') + cid + (f'  ({detail})' if detail and not ok else ''), flush=True)
    fails += 0 if ok else 1


def run(project, *args, root=None):
    cmd = [sys.executable, '-I', str(TOOL), '--project', str(project)] + (['--root', str(root)] if root else []) + list(args)
    return subprocess.run(cmd, capture_output=True, text=True)


def autoload_lines(text):
    out, on = [], False
    for ln in text.split('\n'):
        if ln.strip() == '[autoload]':
            on = True
            continue
        if on and ln.startswith('['):
            break
        if on and '="' in ln:
            out.append(ln)
    return out


def pristine_text(text):
    """text of a project.godot WITHOUT the feature autoload lines of the contract (only inside [autoload]; every other byte stays)"""
    out, on = [], False
    for ln in text.split('\n'):
        if ln.strip() == '[autoload]':
            on = True
        elif ln.startswith('['):
            on = False
        elif on and '="' in ln and ln.split('=', 1)[0].strip() in NAMES:
            continue
        out.append(ln)
    return '\n'.join(out)


def make_root(base, which):
    root = Path(tempfile.mkdtemp(prefix='addauto.', dir=base))
    (root / 'project.godot').write_text(original, encoding='utf-8', newline='')       # the PRISTINE form of --project (see the header)
    for n in which:
        f = root / NAMES[n]
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text('extends Node\n')
    return root


ap = argparse.ArgumentParser()
ap.add_argument('--project', default=str(REPO / 'project.godot'))
ap.add_argument('--no-nested', action='store_true', help='internal: skip the nested run of pristine_copy_ignores_existing_feature_lines (the nested run itself must not recurse)')
a = ap.parse_args()
original = pristine_text(Path(a.project).read_text(encoding='utf-8'))
base = tempfile.mkdtemp(prefix='addauto_t.')
try:
    base_lines = [ln for ln in autoload_lines(original) if ln.split('=')[0] not in NAMES]
    # --- add all, second run, order, base block
    root = make_root(base, NAMES)
    pj = root / 'project.godot'
    r1 = run(pj)
    t1 = pj.read_text(encoding='utf-8')
    lines1 = autoload_lines(t1)
    check('add_all', r1.returncode == 0 and r1.stdout.count('added ') == len(NAMES) and [ln.split('=')[0] for ln in lines1[len(base_lines):]] == list(NAMES), r1.stdout + r1.stderr)
    check('base_block_untouched', lines1[:len(base_lines)] == base_lines and t1.replace('\n'.join(lines1[len(base_lines):]) + '\n', '', 1).count('AnimalHusbandry') >= 1)
    idx = [ln.split('=')[0] for ln in lines1].index('AnimalHusbandry')
    check('added_after_animal_husbandry', all(ln.split('=')[0] in NAMES for ln in lines1[idx + 1:]) and len(lines1[idx + 1:]) == len(NAMES))
    r2 = run(pj)
    check('second_run_is_noop', r2.returncode == 0 and pj.read_text(encoding='utf-8') == t1 and r2.stdout.count('already present') == len(NAMES), r2.stdout)
    # --- everything else of the file is byte-identical: removing the feature lines gives back the original
    check('only_the_feature_lines_were_added', '\n'.join(ln for ln in t1.split('\n') if ln.split('=')[0] not in NAMES) == '\n'.join(ln for ln in original.split('\n') if ln.split('=')[0] not in NAMES))
    # --- missing scripts are skipped, not written
    root = make_root(base, ['LootService', 'HomeManager'])
    pj = root / 'project.godot'
    r = run(pj)
    ls = [ln.split('=')[0] for ln in autoload_lines(pj.read_text(encoding='utf-8'))[len(base_lines):]]
    check('skips_missing_scripts', r.returncode == 0 and ls == ['HomeManager', 'LootService'] and r.stdout.count('skipped') == len(NAMES) - 2, r.stdout)
    # --- the next owner adds its line later: appended behind the existing ones
    (root / NAMES['CollectionLog']).parent.mkdir(parents=True, exist_ok=True)
    (root / NAMES['CollectionLog']).write_text('extends Node\n')
    run(pj, 'CollectionLog')
    ls = [ln.split('=')[0] for ln in autoload_lines(pj.read_text(encoding='utf-8'))[len(base_lines):]]
    check('later_owner_appends_behind', ls == ['HomeManager', 'LootService', 'CollectionLog'], str(ls))
    # --- parallel runs (what the packages of one wave do): 10 processes at once, each adds its own name or all of them
    root = make_root(base, NAMES)
    pj = root / 'project.godot'
    procs = []
    for k in range(10):
        args = [list(NAMES)[k % len(NAMES)]] if k % 2 == 0 else []
        procs.append(subprocess.Popen([sys.executable, '-I', str(TOOL), '--project', str(pj)] + args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True))
    codes = [p.wait() for p in procs]
    t3 = pj.read_text(encoding='utf-8')
    ls = [ln.split('=')[0] for ln in autoload_lines(t3)]
    check('parallel_runs_do_not_corrupt', all(c == 0 for c in codes) and sorted(ls[len(base_lines):]) == sorted(NAMES) and len(set(ls)) == len(ls) and ls[:len(base_lines)] == [b.split('=')[0] for b in base_lines]
          and t3.count('[autoload]') == 1 and not list(root.glob('project.godot.*.tmp')), f'codes {codes}, {ls}')
    # --- refusals leave the file alone
    def refusal(cid, text, args=(), want=3):
        root = make_root(base, NAMES)
        pj = root / 'project.godot'
        pj.write_text(text, encoding='utf-8')
        before = pj.read_bytes()
        r = run(pj, *args)
        check(cid, r.returncode == want and pj.read_bytes() == before, f'exit {r.returncode} {r.stderr.strip()[:100]}')
    refusal('refuses_other_path', original.replace('AnimalHusbandry="*res://scripts/farm/animal_husbandry.gd"', 'AnimalHusbandry="*res://scripts/farm/animal_husbandry.gd"\nHomeManager="*res://scripts/elsewhere/home_manager.gd"'))
    refusal('refuses_unknown_name', original, args=('Bogus',), want=2)
    refusal('refuses_foreign_entry', original.replace('AnimalHusbandry="*res://scripts/farm/animal_husbandry.gd"', 'AnimalHusbandry="*res://scripts/farm/animal_husbandry.gd"\nRogue="*res://scripts/rogue.gd"'))
    refusal('refuses_missing_section', original.replace('[autoload]', '[autoloadx]'))
    refusal('refuses_missing_animal_husbandry', original.replace('AnimalHusbandry="*res://scripts/farm/animal_husbandry.gd"\n', ''))
    dup_line = 'HomeManager="*res://scripts/home/home_manager.gd"'
    refusal('refuses_duplicate_entry', original.replace('AnimalHusbandry="*res://scripts/farm/animal_husbandry.gd"', 'AnimalHusbandry="*res://scripts/farm/animal_husbandry.gd"\n' + dup_line + '\n' + dup_line))
    check('refusal_leaves_file_unchanged', True)       # asserted byte for byte inside every refusal check above
    # --- review F1 r2: a name given twice on the command line is ONE line (the old tool appended HomeManager twice, check_project then said "appears more than once" and a later run never repaired it)
    root = make_root(base, NAMES)
    pj = root / 'project.godot'
    r = run(pj, 'HomeManager', 'LootService', 'HomeManager', 'HomeManager')
    ls = [ln.split('=')[0] for ln in autoload_lines(pj.read_text(encoding='utf-8'))[len(base_lines):]]
    check('dedupes_repeated_names', r.returncode == 0 and ls == ['HomeManager', 'LootService'] and r.stdout.count('added HomeManager') == 1, f'{ls} {r.stdout!r} {r.stderr!r}')
    # --- review F1 r2: a --project that does not exist is a clean refusal (exit 3), not a FileNotFoundError traceback, and nothing is created next to it
    ghost = Path(base) / 'no_such_dir' / 'project.godot'
    r = run(ghost)
    check('refuses_missing_project', r.returncode == 3 and 'Traceback' not in r.stderr and 'REFUSED' in r.stderr and not ghost.parent.exists(), f'exit {r.returncode} {r.stderr.strip()[:120]}')
    empty = Path(tempfile.mkdtemp(prefix='addauto_e.', dir=base))
    r = run(empty / 'project.godot')
    check('refuses_missing_project_creates_no_lock', r.returncode == 3 and 'Traceback' not in r.stderr and list(empty.iterdir()) == [], f'exit {r.returncode} left {[p.name for p in empty.iterdir()]}')
    root = make_root(base, NAMES)
    before = (root / 'project.godot').read_bytes()
    r = run(root / 'project.godot', root=root / 'not_a_dir')
    check('refuses_missing_root', r.returncode == 3 and 'Traceback' not in r.stderr and (root / 'project.godot').read_bytes() == before, f'exit {r.returncode} {r.stderr.strip()[:120]}')
    # a project file that is not UTF-8 text is a clean refusal too (exit 3, file untouched)
    root = make_root(base, NAMES)
    pj = root / 'project.godot'
    pj.write_bytes(b'[autoload]\n\xff\xfe\x00 not text\n')
    before = pj.read_bytes()
    r = run(pj)
    check('refuses_unreadable_project', r.returncode == 3 and 'Traceback' not in r.stderr and pj.read_bytes() == before, f'exit {r.returncode} {r.stderr.strip()[:120]}')
    # --- dry run + file mode
    root = make_root(base, NAMES)
    pj = root / 'project.godot'
    os.chmod(pj, 0o644)
    r = run(pj, '--dry-run')
    check('dry_run_writes_nothing', r.returncode == 0 and r.stdout.count('added ') == len(NAMES) and pj.read_text(encoding='utf-8') == original)
    run(pj)
    check('file_mode_kept', (pj.stat().st_mode & 0o777) == 0o644, oct(pj.stat().st_mode & 0o777))
    # --- fix round RT2: the closed lists of the autoload contract agree (a name added to one and not to the others made the self-test, Fresh or the check_project pin fail one package later)
    sys.dont_write_bytecode = True                      # importing the tool must not leave a __pycache__ next to it
    spec = importlib.util.spec_from_file_location('add_autoload_under_test', TOOL)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    check('contract_names_match_self_test', list(mod.CONTRACT.items()) == list(NAMES.items()), f'tool {list(mod.CONTRACT)} self-test {list(NAMES)}')
    fresh_m = re.search(r'const FEATURE_NODES\s*:?=\s*\[([^\]]*)\]', FRESH.read_text(encoding='utf-8')) if FRESH.is_file() else None
    fresh_nodes = re.findall(r'"([A-Za-z_][A-Za-z0-9_]*)"', fresh_m.group(1)) if fresh_m else []
    check('fresh_feature_nodes_cover_the_contract', fresh_nodes == list(mod.CONTRACT), f'fresh.gd FEATURE_NODES {fresh_nodes} contract {list(mod.CONTRACT)}')
    # --- fix round RT2 (the trap): a project.godot that ALREADY carries feature lines is a valid --project.  t1 is the pristine project after the tool added every line; stripping gives the pristine text back
    # byte for byte, and the whole self-test run against t1 (nested, same script) passes as well - without the pristine copy it failed on add_all / second_run_is_noop / skips_missing_scripts ... as soon
    # as ONE feature line existed.  The nested run gets --no-nested, so it does not recurse.
    stripped_ok = pristine_text(t1) == original and pristine_text(original) == original
    nested_ok, nested_detail = True, 'skipped: this IS the nested run'
    if not a.no_nested:
        dirty = Path(base) / 'dirty_project.godot'
        dirty.write_text(t1, encoding='utf-8', newline='')
        nr = subprocess.run([sys.executable, '-I', str(Path(__file__).resolve()), '--project', str(dirty), '--no-nested'], capture_output=True, text=True)
        nested_ok = nr.returncode == 0 and 'PASS add_all' in nr.stdout and 'PASS second_run_is_noop' in nr.stdout and 'FAIL' not in nr.stdout
        nested_detail = f'exit {nr.returncode}, ' + ', '.join(ln for ln in nr.stdout.split('\n') if ln.startswith('FAIL'))[:200] + nr.stderr.strip()[:100]
    check('pristine_copy_ignores_existing_feature_lines', stripped_ok and nested_ok, f'stripped inverse {stripped_ok}; nested self-test: {nested_detail}')
finally:
    shutil.rmtree(base, ignore_errors=True)
print(f"test_add_autoload: {'PASS' if not fails else 'FAIL'} ({fails} failing check(s))")
sys.exit(1 if fails else 0)
