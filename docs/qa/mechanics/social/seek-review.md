# Blund’s counted hiding game

Blund becomes invisible only at a real routine `hide` post. Three soft existing Glow sprites provide the clue on the same floor; no new painting, light, autoload or input action was added. The normal/ghost clue radii are 260/390 ground pixels, whispers use 320/140 and a find requires 72. Silke’s existing hint choice now follows the live slot, including travel gaps, festival days, family evening and the end of play. Her frozen recordings and original copy are unchanged; three new unvoiced responses cover states the old clock-only hint could misdescribe.

Six scalar flags in the existing game save retain the lifetime total, claimed reward bits and the current game-day slot bits. Midnight does not reset them. The ladder pays at 3/10/24/48/80 finds. Keepsakes check stock, placed ownership and the global loot registry, then use their named rare fallback when already found. The claim bit commits only after acceptance. Full target stores defer the gift; they do not silently sell it. Furniture notifications now respect the economy transaction boundary, so observers and reentrant claims see one committed reward.

The real dialogue acknowledges finds and exposes the progress card; its numbers relocalize using explicit formatting values. Blund’s generated Lua branches use literal tables throughout and add no lint findings. Normal conversation retries pending rewards.

Acceptance:

- `seek-integration-ghost.json`: 747 checks across eight sections, no skips, failures or engine messages. This covers furniture transactions, family data/events/glow, social events/talk and navigation.
- `seek-{animal,fairy,hobbit,ghost}.json`: 82 checks per race, no skips/failures/engine messages. Includes the actual NPC interaction, midnight save/load, every ladder step, stock/placed/registry ownership, full-store retry and a reentrant store observer.
- `seek-final.json`: 543 checks across four sections after adding live hints; no skips/failures/engine messages. All twelve weekday slots and their hints, festival/family/travel/rest states and both independent checker mutants pass.
- `seek-economy.json` is produced by the independent Python policy checker from `seek-economy-source.json`, a dump of 401 live items and 129 recipes. Sellable prizes total 370 gold, or 900 with both fallbacks; no prize becomes a recipe ingredient or set capstone. Real-time pacing uses the base clock, excluding the test fixture’s frozen-clock override: a game week is 70 real minutes. At four finds per game week the final lamp takes twenty game weeks (23.3 real hours); twelve finds per week takes 6.7 weeks (7.8 hours). These are design assumptions, not measured player telemetry.
- `seek-native.json`: six checks with no skips/failures/engine messages. The final shimmer, prize and progress captures were opened and visually inspected. The first native fixture placed the hero inside a planter keepout and hid the clue behind foliage/arrival UI. The final approach uses valid floor, the clue sits above same-floor foliage, and the capture waits for transient arrival feedback to settle.

Copy remains draft for native-speaker review. Approved bitmap assets and the 2,904-entry art ledger are unchanged.
