#!/usr/bin/env python3
"""P13 helper (wave 4): copy the reviewed `rewards = { ... }` block of the four legacy quests from data/features/pending/lua/quests into the quest files P13 rewrote.
Idempotent; touches nothing but the rewards block.  Paths default to the repo this script lives in, so it runs from any directory.

    python tools/features/merge_pending_rewards.py [--pending DIR] [--target DIR] [--check]

--check changes nothing and exits 1 when a quest still differs (P13's gate; the validator's stage p13 rule Q3 proves the same on the stage tree).
Quests: lost_cat, fix_roof, birthday_cake, math_wizard_quiz.  The reviewed rewards also add the friendship block (`friendship = { npc = hearts }`) that P13's QuestManager pays."""
import argparse
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
QUESTS = ('lost_cat', 'fix_roof', 'birthday_cake', 'math_wizard_quiz')
BLOCK = re.compile(r'^rewards = \{[\s\S]*?\n\}\n', re.M)
ap = argparse.ArgumentParser()
ap.add_argument('--pending', default=str(REPO / 'data/features/pending/lua/quests'))
ap.add_argument('--target', default=str(REPO / 'lua/quests'))
ap.add_argument('--check', action='store_true')
a = ap.parse_args()
bad = 0
for q in QUESTS:
    src = (Path(a.pending) / f'{q}.lua').read_text(encoding='utf-8')
    dst_p = Path(a.target) / f'{q}.lua'
    dst = dst_p.read_text(encoding='utf-8')
    ms, md = BLOCK.search(src), BLOCK.search(dst)
    assert ms and md, f'{q}: no rewards block (the target file must keep a top-level `rewards = {{ ... }}` block that ends with a line holding only `}}`)'
    if ms.group(0) == md.group(0):
        print(q, 'already merged')
        continue
    bad += 1
    if a.check:
        print(q, 'REWARDS DIFFER')
        continue
    dst_p.write_text(dst[:md.start()] + ms.group(0) + dst[md.end():], encoding='utf-8')
    print(q, 'merged')
sys.exit(1 if (a.check and bad) else 0)
