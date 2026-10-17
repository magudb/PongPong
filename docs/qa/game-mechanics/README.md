# Mechanics and story review evidence

Base commit: `abec447`. Review: [game-mechanics-2026-10-17.md](../../review/game-mechanics-2026-10-17.md). Godot: 4.7.2, macOS, Apple M3. Worktree/branch: `game-mechanics`. Game source, balance, copy and assets were not changed.

**Historical review snapshot.** Subsequent implementation and acceptance results are in [fixes/README.md](fixes/README.md). To reproduce the original observations below, use a disposable checkout of review commit `0d0ddd6`, which contains the probes and the original game code. Those probes intentionally assert the pre-fix defects and are not acceptance tests for the later implementation. The archived reports below have not been regenerated against changed game behavior.

| Artifact | Mode | Checks | Result |
|---|---|---:|---|
| [baseline.json](baseline.json) | Headless, fast | 1,179 | Pass: core, farm lifecycle/automation, home, quests, garden, mother story |
| [owners.json](owners.json) | Headless, fast | 856 | Pass: animals, economy/transactions, home progression, social/gifts/events, dungeon rules, wardrobe |
| [story-fairy.json](story-fairy.json) | Headless, fast | 204 | Pass: garden + mother story |
| [story-hobbit.json](story-hobbit.json) | Headless, fast | 204 | Pass: garden + mother story |
| [story-ghost.json](story-ghost.json) | Headless, fast | 204 | Pass: garden + mother story |
| [observations.json](observations.json) | Headless, fast | 17 | Observations reproduced; these passes confirm undesirable behavior |
| [story-anchor-checks.json](story-anchor-checks.json) | Headless, fast | 130 | 120 layouts generated; missing witness independently confirmed |
| [native-first.json](native-first.json) / [log](native-first.log) | Native, 1280×720 | 13 before abort | **Fail:** missing floor-2 keeper caused unguarded test lookup to abort |
| [native.json](native.json) | Native, 1280×720 | 37 | Pass on a new generated world; does not erase first failure |

All passing runs have zero failed checks, zero skips and zero unexpected engine errors/warnings. The baseline permits six deliberate negative-test messages; owners permits one. Counts include harness boot checks where present, and repeat some contracts across characters; they are not counts of unique gameplay behaviors. No full-suite or all-race combat acceptance is claimed.

## Reproduce

Run in this worktree, one Godot process at a time. The wrappers create disposable profiles and do not use the player's saves. Fresh worktrees need `tools/dev/worktree.sh refresh game-mechanics` before running tests.

```sh
tests/run_playtest.sh --fast --strict --only=core,farm_lifecycle,forest_mother,secret_garden,quests,home,farm_automation --report=docs/qa/game-mechanics/baseline.json
tests/run_playtest.sh --fast --strict --only=animals,economy,economy_transactions,home_progression,social,social_gifts,social_events,dungeon_run,wardrobe --report=docs/qa/game-mechanics/owners.json
tests/run_playtest.sh --fast --strict --sections-dir=res://docs/qa/game-mechanics/probes --only=mechanics_observations --report=docs/qa/game-mechanics/observations.json
tests/run_playtest.sh --fast --strict --sections-dir=res://docs/qa/game-mechanics/probes --only=story_anchors --report=docs/qa/game-mechanics/story-anchor-checks.json
python3 docs/qa/game-mechanics/analyze_balance.py
```

For the character-specific runs, use `--character=fairy` (then `hobbit`, `ghost`) with `--only=forest_mother,secret_garden`. The baseline covers the animal family. The existing mother-story section also exercises an alternate skin headlessly. These sections seed/give prerequisites; they are state-flow tests, not natural progression playthroughs.

Native capture:

```sh
tools/dev/run_windowed.sh --strict --only=forest_mother --out=docs/qa/game-mechanics/native --report=docs/qa/game-mechanics/native.json
```

Native screenshots were opened and inspected. In particular the memory props sit beside a generated route, the final-account page presents Mother's words, and the legacy tin/flowers remain in the garden. Capture setup fills the backpack, grants story prerequisites and moves the player to interaction locations; screenshots must not be presented as an unassisted run. Original failing native world seed was not retained. Preserve `native-first.json` and its log when rerunning.

## Observation semantics

[mechanics_observations.gd](probes/mechanics_observations.gd) exports the loaded runtime catalog and actual shop prices to [runtime-data.json](runtime-data.json). It pays normal construction costs from a granted setup budget, adopts animals through production APIs, and advances days without changing animal records. Brushing/play with no feeding yielded 70 eggs in 30 mornings, including 65 at zero fullness. A matured calf yielded five milk with no pail. It also presses the advertised Collection input and inspects the guardian objective bindings. The random animal amount is seeded for this observation. Assertions verify the observation, not desired fixed behavior.

[story_anchors.gd](probes/story_anchors.gd) generates 40 fixed seeds each for floors 2, 6 and 10. [story-anchors.json](story-anchors.json) records all 120 samples. Floor 10, sample index 35, seed `3275138988032679373` has zero keepers; generation and the existing independent verifier both accept it. [missing-witness.map](missing-witness.map) preserves that exported layout. This is a fixed existence proof, not a confidence interval or proof that every missing native NPC has the same cause.

[analyze_balance.py](analyze_balance.py) uses the exported catalog to produce [balance.json](balance.json). It records its assumptions beside crop, processing and mature-animal comparisons. Prices include current catalog offers, which do not imply that gated/seasonal shops are accessible from a fresh save. Raw sale comparisons do not capture crafting, gifting, aesthetics or the player's time. No AI images or asset edits were made for this review.
