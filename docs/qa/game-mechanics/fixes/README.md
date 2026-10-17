# Mechanics and story follow-up

Implements the findings from review commit `0d0ddd6` on the `game-mechanics` worktree. The original review was merged to `main` before this implementation started. Its reports remain historical evidence; the reproduction probes deliberately describe the old defects and must be run against that review commit, not used as fixed-game acceptance tests.

| Finding | Result |
|---|---|
| GM-01: missing witness | Generation rejects/retries layouts missing a requested keeper. The independent verifier checks both count and identity. The fixed missing-witness seed now retries into a valid layout; deleting the keeper from exported text fails verification. |
| GM-02: unfed production | A morning's periodic production needs a ration of 10 fullness before daily decay. Initial food reserves still count. Empty reserves pause new produce; existing produce, animals and friendship remain. Bond keepsakes still reward companionship. |
| GM-03: inert pail | Milk stays ready until the player owns a pail. The care screen explains the requirement, and using a held pail beside a cow collects milk. The reusable tool is never consumed. Goats were removed from its description. |
| GM-04: guardian wording/catch-up | Objectives and an unvoiced clarification explicitly ask for victories. The recorded offer keeps its exact original wording. Existing permanent boss-clear flags satisfy earlier victories when the quest is accepted/loaded; reporting to Oak remains required and rewards only once. |
| GM-05: reading-only investigation | Lamp repair has three independently saved stitches and reveals the map with light. The traveller's frame requires her own name, with gentle retries and a visible name change. The stone turns both ways and must match the visible map clue. Cancelling a panel cannot complete the task. |
| GM-06: opening motivation | The king's opening includes the mother search and a concrete lead to Hoppe/the garden for every hero. The existing voiced letter remains unchanged; the added line is unvoiced draft copy. |
| GM-07: wool balance | Sheep yield 3–4 base wool instead of 1–2. Existing 15g feed is now presented as farm feed and is accepted by rabbits, sheep, cows and deer as well as poultry. Favourite foods and their bonuses remain. |
| GM-08: false quest giver | Forest chapters use a translated investigation source and no NPC portrait. Ordinary quests retain their actual givers. Metadata validation checks the two attribution forms. |
| GM-09: advertised dead key | Collection was removed from the playing instructions while its optional screen is absent. |
| GM-10: premature conclusions | An early final-route discovery records a standalone observation. The marker and journal show the assembled interpretation after S06 completes. Early evidence and chapter catch-up remain available. |

There is also an explicit unarmored-enemies qualifier on the club's stun description. All changed copy remains draft Danish/English; the refreshed review queue does not mark anything as human reviewed. [Copy lint](copy-lint.json) reports no findings for the five touched CSVs.

## Persistence and design boundaries

Dungeon generator version is now **2** because retrying a formerly accepted layout can change its cell identities. The existing loader discards incompatible in-progress layout deltas and retains runestones/deepest progress; persistent story discoveries remain independent of those cells. The regression checks the version-1 transition explicitly. Inventory/save schema is unchanged.

Restoration work uses versioned scalar flags. Each stitch or stone turn commits before observers and autosave. Previously recorded story evidence is treated as already completed work, so old saves never repeat it to recover access to their map. Wrong answers cost nothing, partial work can be resumed, and no paid/random material is required.

The new activities reuse the existing painted props, theme, dialogue controls and small light/line overlays. No game image assets were replaced or generated. The mother’s chosen bittersweet fate, family relationships and legacy homecoming remain. The memory clearing is still part of a procedural floor; a fully staged house/Root Scribe scene and broader town dialogue variation remain design polish. The authored tier-6 home gate remains as reviewed.

For wool, at happiness >=80 and immediate collection, rabbit gross remains 12g/day and sheep gross rises from 10g/day to 18g/day. With daily play, the 15-fullness/day drain uses half a 15g feed on average: modelled feed costs are 7.5g/day, leaving 4.5g/day for rabbits and 10.5g/day for sheep before building, animal and labour costs. This is a mature steady-state comparison, not observed full-playthrough ROI. The crop/processing tables in the original review are unchanged.

## Verification

The [verification manifest](VERIFICATION.json) records the report counts and final source binding. All final runs have zero failed checks and no unexpected engine messages.

| Run | Checks | Explicit skips |
|---|---:|---:|
| Focused regression, 19 sections | 2,377 | 0 |
| Native care, held tool and story, 3 sections | 138 | 0 |
| Fairy / hobbit / ghost story | 206 each | 0 |
| Town loop, weapons, wardrobe UI and farm UI audit | 286 | 4 |
| Main checkout after merging implementation `02f29ec` | 198 | 0 |

The [main-checkout run](main.json) exercises the new mechanics regression, mother story and quest contracts from the actual `main` project after its imports refresh.

The four integration skips are screenshot comparisons that require windowed checkpoint runs. The native checks above separately exercise the changed care/story screens. The town extension's 584 owner checks and eight scenario checks pass, all eight deliberate town regressions are caught, and [both town proofs match the current source](town-proof-check.json). The integration run's one allowed engine message belongs to an intentional negative test.

The focused regression is [regression.json](regression.json). It includes generation/fallback verification, farm lifecycle/automation/playthrough, animal care, economy/transactions, ten-tier home progression, quest/data contracts, dungeon save/progression rules, wardrobe, gifts, the first morning, garden and mother story. [mechanics_review_fixes.gd](../../../../tests/sections/mechanics_review_fixes.gd) adds the fixed seed and a deleted-witness negative control, a 30-morning unfed care loop, feeding recovery, safe milk retention, care-screen messaging, a real held-pail interaction, prior boss catch-up, repair cancellation/partial-save recovery, visible map reveal, retryable name/stone work, source attribution, out-of-order copy and old-save compatibility.

Native checks cover the care screen, held pail, garden/forest interactions and finale at 1280×720. New work panels are captured in Danish and English. Headless story runs additionally cover fairy, hobbit and ghost families; the main regression covers animal heroes. These use explicit test grants and direct boss-state setup where documented in the existing harness; they are not a fresh unassisted save-to-finale playthrough or a full-suite/all-race combat run.

`story-contract-first.json` retains an intermediate failed run: the older metadata test demanded an NPC giver for every quest. The test was updated to require either a real roster giver or a translated self-directed source, while continuing to validate tags and locations. It was not bypassed. The original review's missing-witness native failure remains separately retained in the parent directory.

`integration-voice-first.json` retains the integration check that caught a changed recorded offer. The exact original text was restored; the clearer goal uses an additional unvoiced line and the journal objectives. [Copy/audio audit](copy-audit.json) checks the protected text and audio hashes. Frozen manifests and recordings were not regenerated to accept a mismatch.

Run one engine at a time from this worktree, with disposable profiles supplied by the wrappers:

```sh
tests/run_playtest.sh --fast --strict --only=mechanics_review_fixes,quests,data,data_registry,dungeon_gen,dungeon_floors,dungeon_run,economy,economy_transactions,home_progression,animals,wardrobe,social_gifts,farm_lifecycle,farm_automation,farm_playthrough,forest_mother,secret_garden,farm_first_morning --report=docs/qa/game-mechanics/fixes/regression.json
tests/run_playtest.sh --fast --strict --character=ghost --only=forest_mother,secret_garden --report=docs/qa/game-mechanics/fixes/story-ghost.json
tools/dev/run_windowed.sh --strict --only=forest_mother,animals,mechanics_review_fixes --out=docs/qa/game-mechanics/fixes/native --report=docs/qa/game-mechanics/fixes/native.json
```

Use `fairy` and `hobbit` for the other story variants. Passing new regression assertions verify the fixed behavior; passing the old historical observation probes had the opposite meaning.
