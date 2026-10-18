# Fresh-save journey acceptance — 18 October 2026

Work is based on `main` at `5fc72b2`, in the `game-mechanics` worktree.

Implementation: `cb9f899`, merged to `main` as `9fb05e6`. The merged checkout passed a further [208-check normal-speed control run](main-controls.json), with no failures, skips or engine messages. Its [source proofs](main-source-bindings.json) match the worktree's validated source bytes.

## Changes found during play

- Entrances accept the player only while walking freely. Dodges, swings, tool work, dialogue and knockback cannot carry the player through an entrance in the middle of an action. Walking out and back in still works. The retained [before trace](combat-stairs-before-trace.json) shows seven dodge-triggered floor changes; the associated [failed report](combat-stairs-before.json) stops at the missed route stone.
- A garden helper's pending reply and a witness's new mother account stay on the first conversation page. Ordinary quests, gifts and recall topics remain available through the existing bounded overflow pages. Scripted conversations are unchanged. [Before report](hidden-story-topic-before.json).
- Natteblik's sleeping message and journal lead explain that the forest clock is frozen: return by lift, wait in town until dark, then enter again. The calendar and witness rules are unchanged.
- The mother's journal scrolls its selected account into view after rebuilding the rows, while keeping focus on the tab. The native check exposed the final account's text alongside an off-screen selected row; the [before regression](journal-scroll-before.json) reproduces entering the tab after the book has opened.
- Combat remembers the precise ground aim separately from the eight painted facing rows. Keyboard aim assistance covers half a direction sector; mouse assistance retains its previous angle. This removes spear blind sectors without changing damage, reach, attack timing or the spear's cone. [Before report](spear-aim-before.json) and [trace](spear-aim-before-trace.json) retain the stationary thorn bush that survived 277 swings. Climbing also updates the retained aim: a real ladder descent exposed a sideways next attack while the pose faced down ([before report](ladder-aim-before.json)); the normal-speed control run verifies the corrected landing.

## What the continuous driver does

`tests/acceptance/journey.gd` starts through the real title and character screens and consumes the full first morning. It plants, waters, harvests and ships the starter crops, collects ordinary mail, restores the garden through actual helpers and work panels, earns more income from purchased/awarded seeds, buys suitable gear and supplies, wins the real guardian fights, records the investigation, brings the legacy home, pays for the first house upgrade, saves, Continues and resumes free play.

The driver uses normal movement, entrances, interactions, shop controls, equipment ownership, combat actions, resting and save services. It does not grant gold/items, assign quest/boss flags, teleport the player, change enemy/weapon definitions, assign health or override the calendar. `--fast` advances normal physics faster than wall time. The forest's own pause and default oil rules remain active. The driver knows routes and the clues' answers; this is automated progression evidence, not a human discoverability or enjoyment sign-off.

All three guardian victories are required. An optional roaming enemy with no walkable approach after three route attempts is left alive and explicitly recorded in the trace; a flying bat beyond the walkable route exposed the earlier, unnecessary requirement to hunt every enemy. Required encounters, evidence and travel gates are never bypassed.

The dedicated `tests/lib/journey_walker.gd` controller plans with the real player footprint, avoids unintended entrances and moving citizens, follows bridge mouths and stops for threats. Its finer city graph and combat-support hook belong to this long acceptance run. The existing town-loop walker retains its original behaviour; the normal-speed town gate exposed the need to isolate the two controllers. They do not change the authored world, production NPC routes or artwork.

It honours the requested walking timeout, keeps to the centre line on bridge crossings, chooses a clear dodge side that continues its route, and retries a crowded walk up to three times by replanning from the actual position. It lets movement and actions settle before pressing E and checks that the intended evidence encounter opened. The ghost's first return exposed a controller sidestep into the platform rail; a native replay reached the garden after replanning the approach. A later pond-side fight exposed repeated backwards dodges with no swings; the corrected earned-save continuation won the fight and completed the journey. No city collider, pond or painted boardwalk was changed.

Checkpoints are written through SaveManager in a disposable profile. Optional `JOURNEY_RESUME=/absolute/path/to/earned-save.json` is for diagnosis and native spot checks; these runs are labelled continuations. Fresh acceptance must omit that variable and finish with `verified_fresh_journey`. Earlier diagnostic runs are retained under `diagnostics/`; they are not acceptance results.

## Reproduce

Run one engine at a time:

```sh
tests/run_playtest.sh --fast --strict --sections-dir=res://tests/acceptance --only=journey --timeout=1900 --report=docs/qa/journey/fresh-animal.json
tests/run_playtest.sh --fast --strict --character=ghost --sections-dir=res://tests/acceptance --only=journey --timeout=1900 --report=docs/qa/journey/fresh-ghost.json
tests/run_playtest.sh --fast --strict --only=journey_regressions,player,weapons --report=docs/qa/journey/aim-contracts.json
```

The long calendar scenario is separate from the default section directory so an ordinary-speed regression run does not spend hours waiting for crop days. Small defect regressions remain in the default suite. Their physical stair test drives an actual dodge into an Area2D, records the entered state, then walks out and back to verify intentional travel. Aim checks include analog movement and real spear hits at 30 degrees and a keyboard sector boundary.

## Verification

| Check | Result |
| --- | --- |
| [Fresh animal journey](fresh-animal.json) / [trace](trace-animal.json) | 1,002 checks; day 20, tier-2 house, 787g |
| [Fresh ghost journey](fresh-ghost.json) / [trace](trace-ghost.json) | 1,025 checks; day 20, tier-2 house, 583g |
| [36 affected-system sections](regression.json) | 3,121 checks; no failures |
| [Final story/control regressions](final-regression.json) | 513 checks; no failures or skips |
| [Normal-speed controls](controls-normal.json) | 208 checks; no failures or skips |
| Controls for [animal](controls-animal.json), [fairy](controls-fairy.json), [hobbit](controls-hobbit.json), [ghost](controls-ghost.json) | 833 checks total; all pass with no skips |
| [Native earned-save continuation](native-homecoming.json) | 30 checks; both journal languages inspected |
| [Native controls and renderer budgets](native-controls.json) | 64 checks; no failures or skips |
| [Normal-speed town milestone gate](town-gate-normal.json) / [log](town-gate-normal.log) | 190 checks; no failures or skips; original timing limits |
| [Current source bindings](source-bindings.json) | Whole data extension and all eight producer mutants pass |
| [Copy lint](copy-lint.json), [copy/audio audit](copy-audit.json), [style snapshot](style-check.log) | All pass; 2,974 reviewed visual/theme assets |

Both fresh runs start at New Game, finish with `verified_fresh_journey`, win all three guardians, restore the garden, pay for the first house upgrade and verify saved progress through Continue and a further ordinary day. Neither uses an earned checkpoint. No optional enemy was left outside the route in these two successful runs.

The broad run has one inapplicable absent-SocialManager fallback fixture: that service is installed. Its 22 explicitly allowed messages are intentional malformed-data/unknown-character negative controls. Every report has zero unexpected engine errors, warnings and known-issue exemptions. The final story/control run covers the later ladder and journal fixes.

The [native benchmark log](native-controls.log) retains the measurements on this Apple M3 Mac: mean presented frame times were 1.95 ms in the seed shop, 2.83 ms in Hyggebyen, 3.15 ms in Treetop City and 2.91 ms on the farm. The city used 235 draw calls; total renderer textures after 20 warmed looks were 325.63 MB. These are source-project measurements on this machine.

Timing outliers occurred while the Mac was idle and background jobs were busy. The unchanged `main` baseline also failed timing limits ([comparison](diagnostics/main-baseline-timing.json)). The final normal gate passed with a temporary macOS awake assertion and no threshold changes. Its one allowed message deliberately tests a content-drift warning.

## Scope

This covers the main garden/mother journey and the first paid house upgrade. It does not replace human playtesting, all ten house tiers earned in one save, every social route, low-end hardware checks or packaged-build testing. Frozen recordings and approved painted asset bytes are preserved; the changed copy remains draft.
