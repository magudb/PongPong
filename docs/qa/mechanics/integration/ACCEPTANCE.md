# Single-player mechanics acceptance

The planned single-player mechanics are implemented, verified and merged into local `main` (`e32e298`) from `codex-mechanics`. The chosen bittersweet mother-story resolution returns her legacy to the restored garden and preserves free play. Homes/furniture/services, animals/buildings, towns/shops, social events/relationships, festivals, dungeon progression/combat, loot/crafting/appraisal and saved clothing/equipment are usable. The [playing guide](../../../PLAYING.md) documents the controls.

| Verification | Result | Evidence |
|---|---|---|
| Full headless regression | 16,425 checks, 130 sections, zero failed checks or unexpected engine messages | [report](full-headless.json), [log](full-headless.log) |
| Final cache/equipment/boss/UI regression | 531 checks, zero failures; eight native-only skips | [report](texture-repair-headless.json) |
| Final native integration | 878 checks, 14 sections, zero failures/skips/engine messages | [report](final-native.json), [log](final-native.log) |
| Final terrain/revisit regression | 677 checks, zero failures; nine native-only skips | [report](terrain-lifetime-headless.json) |
| Final enemy update | 109 headless and eight native checks, zero failures/skips/engine messages | [headless](enemy-update-headless.json), [native](enemy-update-native.json) |
| Native area/texture budgets | 29 checks, zero failures/skips/engine messages | [report](native-budget-final.json), [repairs](NATIVE_REPAIRS.md) |
| Town wave 7 and source proofs | All required installed consumers and native festival capture; eight producer mutants caught after a clean control; 137 bake, 584 owner and eight extension scenario checks | [wave table](town-wave-7.json), [extension](../../m1b-milestone/loop-extension.json), [mutants](../../m1b-milestone/loop-mutants.json) |
| Combat acceptance | 180/180 seeded boss wins within time/damage limits; 100/100 completed ambushes dodged | [combat](../combat/ACCEPTANCE.md), [bot data](../combat/bot.json) |
| Dungeon data/economy | 125 staged rules, all 57 mutants caught, all nine pacing-model gates pass | [validation](../loot/VALIDATION.md) |
| Harness and proof boundaries | 66 harness self-tests and eight source-binding controls pass | [harness](harness-selftest.log), [binding](proof-binding.log) |
| Art/copy/voice | 2,925 reviewed visual/theme assets match; strict 4,415-key localization; 296 complete voice paths, zero deferred | [style](style-check.log), [copy](../copy/REVIEW.md) |

The full headless pass predates only the final preview/terrain lifetime and terrain-batching repairs; the affected systems are covered by the focused regressions and current native runs. Its 156 explicit skips include native-only rendering, delegated owner-specific checks, optional/absent-service paths and the then-stale town proofs. Final native acceptance has no skips; current source proofs and wave 7 require every installed town consumer. The long real-combat run was completed after the warning fixes and is retained separately, rather than repeated for UI-only changes. Earlier failing baseline/initial reports and exploratory performance probes are diagnostic history, not acceptance.

The final town proof binding is `b512ac867eda2b2e4e36407b5584c405b4b067c2415908b2cd7f3561665006e7`. It covers production/test/tool code, data, localization, launchers, imports, project settings and review policies; generated cache copies are excluded. Historical loadout and earlier milestone proofs remain archived with their original source references. Current immutable guide comparisons retain complete raw captures/scores and reject a slot-chrome mutation. The combined-run contact pages and selected full-size final images were inspected by the implementing agent; [visual review](VISUAL_REVIEW.md) records the scope.

Native performance figures are measured on Apple M3 at 1280×720 using Godot 4.7.2 Compatibility. RenderingServer CPU timing, callback costs and whole-frame timing are reported separately; unsupported GPU timing is not treated as zero work. The dense floor's variable whole-frame samples remain recorded. The rainy town has limited margin under its 4 ms target; no low-end or universal frame-rate claim is made. Pacing results are model assumptions, not player telemetry.

Eleven human voice paths are preserved alongside 285 Sara placeholders. Native-speaker copy and aesthetic listening review remain editorial work. No human play-session sign-off is claimed. Children, multiplayer, yearly birthday cards and a fifth friendship event are later work; the greenhouse remains opt-in. No remote push is requested.

Post-merge verification passes 715 checks across nine sections on main, with zero failures or unexpected engine messages. Seven expected negative-fixture messages are recorded. The only skip is the absent-SocialManager fallback because the real autoload is installed. The 2,925-asset style audit, both current source proofs and all 57 route-input hashes pass. Every finished worktree head is an ancestor of main. See [main verification](MAIN_VERIFICATION.json) and [smoke log](main-smoke.log). No remote push was performed by this task.
