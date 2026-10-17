# Single-player mechanics completion

Worktree: `codex-mechanics`. Main has not yet received this task’s commits. Finish and verify the full authorized scope before merging locally; no remote push is requested.

Completed packages include usable homes and furniture, buildings and animal care, deterministic twelve-floor forest generation, dungeon rules and combat, equipment/arsenal and forging, loot/appraisal, forest resources, the action HUD, painted weapon and loot assets, forest lighting/dressing, and the complete mother investigation with the chosen bittersweet ending and garden legacy. The original approved art remains protected by the explicit review ledger.

The latest completed package is the social scene and festival-activity runtime (`9f23f2a`): 811 passing integration checks, 114 native checks and inspected screenshots. The mother-story package is `8dbd96b`: all eight heroes checked, four native body families, 21 generated story-floor placements and the strict art catalog with no gaps. The current ledger contains 2,906 reviewed visual/theme assets.

The fixed-festival and extended-town package is complete: nine festivals, eighteen scenes, five markets, live painted decoration, ten extended rooms, seven additional citizen schedules, the post-office location screen and 66 keeper greeting rows. Acceptance: 1,988 checks across 15 sections, 500 focused audit checks and 547 native checks; no failures or engine errors/warnings. Native product captures were visually inspected and the post guide fixture was pinned. The live 34-citizen social simulation meets the original limits using the full 06:00–02:00 clock; existing ratchet bounds were only tightened.

The forty citizen heart scenes, eleven Natlys scenes, thirty-six family festival greetings and disposable family glow are complete. Acceptance includes 1,297 passing integration checks, ten native checks and inspected captures; prerequisite/conditional-step mutants are checked in both validator implementations. Staged scenes hide HUD/sign clutter and choose visible floor on the same platform.

Counted Natlys hide-and-seek is complete: actual routine slots, saved daily/lifetime counts, distance clues, live Silke hints, the five-step lamp ladder, deferred full-store claims and keepsake ownership/registry fallbacks. Evidence: 747 integration checks, 82 focused checks per race, 543 final checks and six native checks; no failures or engine messages. All three final native captures were opened and inspected.

The three Natlys errands are complete, including the saved named lost-property owner/item, deferred parcel pickup, real gift completion and weekly cooldown. Acceptance: 308 quest/story/garden checks, 903 broader quest/social/NPC/registry/save/navigation checks and four native checks; no failures or engine errors/warnings. The journal capture was inspected. The two historical dungeon-completer skips now exercise real generated floors.

Relationships, wedding and household mechanics are complete. The special gifts require explicit confirmation and preserve ordinary gift limits; the calendar uses a safe Sunday, missed weddings postpone without penalty, partners retain their jobs and perform one saved daily chore. Real weekly visitor history/guests and parties survive saves, with stable room actors. The festival planner now honours early departure times. Evidence: 1,978 schedule/social checks, 1,574 final package checks, all four playable races and inspected native captures. The two painted icons and exact prompts are saved; the art ledger contains 2,906 entries. Home fixtures were updated for real starter equipment/storage, and the obsolete social-derived-data skip was replaced by live coverage.

Seasonal farm dressing is complete: sixteen markers, nineteen new painted assets with saved prompts/sources, four seasonal apple trees and one bounded particle family. Acceptance: 1,026 broader checks (one existing manual-render skip), sixteen native checks, all nine captures inspected, strict 2,925-asset style ledger green and the original particle cost budget met.

Audio integration is implemented: bounded cue logging and pooling, area/rain/festival ambience, surfaces and footsteps, equipment/social/town hooks, 44 SFX, nine ambience loops and fourteen sparse scores. Fourteen human originals are preserved and eleven reused; 175 Sara placeholders are generated, while 110 draft social voice rows await the copy pass. Acceptance: 1,534 integration checks, six independent waveform/pipeline tests and native mixer/voice-indicator checks. Source-bound town proofs await the final source refresh.

Home services and the integrated UI repairs are complete (7b45bb1): real oven baking, persisted accurate forecasts, consent-gated saved royal visit, all four journal tabs, explicit focus navigation and inspected native UI/forest captures. The calendar fixture is bounded on reopen in logical and native pixel checks.

Dungeon validation/pacing is implemented: 125 full-stage rules, eleven added negative probes, fifteen selected pipeline mutants caught and all nine P1 gates passed. See loot/VALIDATION.md. Remaining work is combat/performance acceptance, final copy, town-loop consumers/proofs and full integration.

Still required before the full task is complete:

- Finish the social copy review and bake its 110 deferred voice rows; preserve frozen human recordings.
- Finish combat/performance acceptance and the complete validator mutation pass.
- Resolve remaining baseline integration failures and implement all installed town-loop consumers; run full headless/native regression, refresh source-bound town proofs, update completion documentation and merge finished work to local main.

The greenhouse remains opt-in. Children, multiplayer, a fifth heart scene and yearly birthday cards are outside this planned single-player scope. Copy remains draft until native-speaker review; visual captures are inspected by the implementing agent.

For the final town proof refresh, first archive the live `fc6df2244d8570a9d28203b8daad0f3bc8dceeb442567abb238f9a86eab99818` manifests and raw directories into `docs/qa/loadout/source-proof-fc6df224/`, and repoint the loadout acceptance references. Then regenerate extension and mutation proofs from the final committed source. Preserve older archived evidence.
