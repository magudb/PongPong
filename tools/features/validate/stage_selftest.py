#!/usr/bin/env python3
"""Self-test of the validator STAGES (review RV-P2): three green stages on simulated repos and three negative controls.

    python3 tools/features/validate/stage_selftest.py [--work DIR]

The simulated repos are overlays (`run_validate.sh --src`): a file is taken from the overlay when it exists there, else from the repo.
  sim p13   P13's wave: the four legacy quests with the reviewed `rewards` blocks merged by tools/features/merge_pending_rewards.py (also proves the tool: merge, merge again = no-op, --check = 0)
  sim p14   P14's wave: sim p13 + the three dialogue modules with the quest_accept branches in lua/dialogue/
Expectations (all must hold):
  f1 on the repo                 green                      (the repo at the time: legacy quests/dialogue, the pending references stand in)
  p13 on sim p13                 green, rule Q3 present
  p14 on sim p14                 green, rule S13 runs on the 'real' dialogue files
  p13 on the repo (not landed)   RED: the legacy quests lack the reviewed rewards (S8 / R3 / Q3 / Q2 ...)
  p14 on sim p13 + legacy oak    RED: S13 (P14 forgot the snurresvampen offer)
  p14 on the repo                runner stops with exit 5 and "stage p14 needs lua/dialogue/fairy_king.lua"
"""
from __future__ import annotations
import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
FEAT = HERE.parent
REPO = FEAT.parents[1]


def run(stage: str, src: Path | None, work: Path, rep: Path) -> tuple[int, str]:
    cmd = ['bash', str(HERE / 'run_validate.sh'), '--stage', stage, '--work', str(work), '--reports', str(rep)]
    if src:
        cmd += ['--src', str(src)]
    r = subprocess.run(cmd, capture_output=True, text=True, env={**os.environ, 'PYTHONDONTWRITEBYTECODE': '1'}, timeout=1500)
    return r.returncode, r.stdout + r.stderr


def failed_ids(out: str) -> list[str]:
    return [ln.split()[1] for ln in out.split('\n') if ln.startswith('[FAIL]')]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--work', default=os.environ.get('TT_FEATURES_SIM_WORK', str(FEAT / '_stage' / 'sim')))
    a = ap.parse_args()
    root = Path(a.work)
    if root.exists():
        shutil.rmtree(root)
    (root / 'p13' / 'lua' / 'quests').mkdir(parents=True)
    (root / 'p14' / 'lua' / 'quests').mkdir(parents=True)
    (root / 'p14' / 'lua' / 'dialogue').mkdir(parents=True)
    (root / 'p14oak' / 'lua' / 'quests').mkdir(parents=True)
    (root / 'p14oak' / 'lua' / 'dialogue').mkdir(parents=True)
    legacy = REPO / 'data/features/pending/legacy_base/lua/quests'
    pend = REPO / 'data/features/pending/lua'
    ok_all = True

    def expect(name: str, cond: bool, detail: str = '') -> None:
        nonlocal ok_all
        ok_all &= cond
        print(f"[{'OK' if cond else 'BAD'}] {name}   {detail}", flush=True)

    # --- P13's wave: legacy quests + merge_pending_rewards.py
    for q in ('lost_cat', 'fix_roof', 'birthday_cake', 'math_wizard_quiz'):
        shutil.copyfile(legacy / f'{q}.lua', root / 'p13' / 'lua' / 'quests' / f'{q}.lua')
    mp = [sys.executable, '-I', str(FEAT / 'merge_pending_rewards.py'), '--target', str(root / 'p13/lua/quests')]
    r0 = subprocess.run(mp + ['--check'], capture_output=True, text=True)
    r1 = subprocess.run(mp, capture_output=True, text=True)
    r2 = subprocess.run(mp, capture_output=True, text=True)
    r3 = subprocess.run(mp + ['--check'], capture_output=True, text=True)
    expect('merge_pending_rewards: --check fails before, merge, merge again is a no-op, --check passes after',
           r0.returncode == 1 and r1.returncode == 0 and r1.stdout.count('merged') >= 4 and 'already merged' in r2.stdout and r2.stdout.count('already merged') == 4 and r3.returncode == 0, f'{r0.returncode}/{r1.returncode}/{r2.returncode}/{r3.returncode}')
    # P13's own rewrite also makes lost_cat one-shot with its PLAN giver (meta block); only the rewards block comes from the merge tool
    lc = root / 'p13/lua/quests/lost_cat.lua'
    meta = re.compile(r'^meta = \{[\s\S]*?\n\}\n', re.M)
    lc.write_text(meta.sub(lambda m: meta.search((pend / 'quests/lost_cat.lua').read_text(encoding='utf-8')).group(0), lc.read_text(encoding='utf-8'), count=1), encoding='utf-8')
    shutil.copytree(root / 'p13/lua/quests', root / 'p14/lua/quests', dirs_exist_ok=True)
    shutil.copytree(root / 'p13/lua/quests', root / 'p14oak/lua/quests', dirs_exist_ok=True)
    for d in ('guard_oak', 'fairy_wizard', 'fairy_king'):
        shutil.copyfile(pend / f'dialogue/{d}.lua', root / 'p14/lua/dialogue' / f'{d}.lua')
    # P14 "forgot" Oak's offer: the legacy guard_oak.lua of the baseline (data/features/pending/legacy_base) stands in, the other two are the reference modules
    shutil.copyfile(REPO / 'data/features/pending/lua/dialogue/fairy_wizard.lua', root / 'p14oak/lua/dialogue/fairy_wizard.lua')
    shutil.copyfile(REPO / 'data/features/pending/lua/dialogue/fairy_king.lua', root / 'p14oak/lua/dialogue/fairy_king.lua')
    shutil.copyfile(REPO / 'data/features/pending/legacy_base/lua/dialogue/guard_oak.lua', root / 'p14oak/lua/dialogue/guard_oak.lua')

    w, rep = root / 'w', root / 'rep'
    rc, out = run('f1', None, w, rep)
    expect('stage f1 on the repo is green', rc == 0, re.search(r'RESULT: .*', out).group(0) if re.search(r'RESULT: .*', out) else out[-200:])
    rc, out = run('p13', root / 'p13', w, rep)
    expect('stage p13 on sim p13 is green and runs Q3', rc == 0 and '[PASS] Q3 ' in out, re.search(r'RESULT: .*', out).group(0) if re.search(r'RESULT: .*', out) else out[-200:])
    rc, out = run('p14', root / 'p14', w, rep)
    expect('stage p14 on sim p14 is green (S13 on the real dialogue files)', rc == 0 and '[PASS] S13 ' in out, re.search(r'RESULT: .*', out).group(0) if re.search(r'RESULT: .*', out) else out[-200:])
    rc, out = run('p13', None, w, rep)
    f = failed_ids(out)
    expect('negative control: stage p13 on the repo (P13 not landed) fails Q3 and more', rc == 1 and 'Q3' in f, f'failing: {f}')
    rc, out = run('p14', root / 'p14oak', w, rep)
    f = failed_ids(out)
    expect('negative control: stage p14 where P14 forgot the offer of Oak fails S13', rc == 1 and 'S13' in f, f'failing: {f}')
    rc, out = run('p14', None, w, rep)
    expect('negative control: stage p14 on the repo stops with a clear message', rc == 5 and 'stage p14 needs' in out, out.strip().split('\n')[-1][:120])
    print('STAGE SELF-TEST', 'PASS' if ok_all else 'FAIL')
    shutil.rmtree(root, ignore_errors=True)
    return 0 if ok_all else 1


if __name__ == '__main__':
    sys.exit(main())
