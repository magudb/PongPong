# Farm completion review

The farm now supports a complete planting, watering, harvesting, shipping and reinvestment loop. The greenhouse, sprinklers and processing machines are included following the user's explicit scope choice. Work was developed on `codex-farm-completion` and incorporates main's `f05c5c8` frost-kale and Root Scribe changes, plus the preceding fish-feed and quest fixes.

## Player behavior

- Harvesting retains tilled soil and today's watering. Strawberries and glow berries regrow after four watered nights. Dry days pause growth; crops outside their supported season wither and can be cleared with the scythe. Axes and pickaxes can deliberately clear a living crop.
- Hold the use button while moving to tend successive cells. Each target is used once until the target or selected item changes. Releasing, opening a modal or travelling resets held use. Ripe crops show a localized E prompt and take priority over unrelated nearby interactions.
- B opens Farm upgrades. The house shortcut uses the existing ten-tier builder. The east field adds 42 plots for 800 golden acorns. The coop, barn and animal house each have three capacity tiers; expansion pays once, completes after the advertised number of days and preserves the existing animals and capacity during construction.
- Basic sprinklers water four adjacent cells, quality sprinklers eight. They apply the new morning's watering after yesterday's crop growth, including when the clock rolls at 02:00. Moonflowers still need watering in their night window.
- Preserves jars consume one crop and finish in two game days; kegs finish in three. Collection requires backpack space. A loaded machine cannot be picked up, and saved batches retain their input, output and completion day.
- At home tier 2, the greenhouse costs 1,500 golden acorns, 60 wood, 30 stone and 8 glass panes and takes three days. Its painted door, interaction target and return spawn agree. It contains twelve year-round beds, a self-service seed shelf and a walkable exit. Rain stays outside; indoor crops and equipment persist across travel and saves.
- All eleven crops, including main's frost kale, have painted art, greenhouse seeds, preserves and juice. Shop and inventory seed details use uncapped labels and the live crop definitions for seasons, first harvest and regrowth. Native all-seed checks cover Danish and English. Carrot and turnip seed stocks support a fully watered expanded field across the seed shop's Sunday closure.

The behavioral reference was the [Stardew Valley crop loop](https://wiki.stardewvalley.net/Crops): watering, retained soil, repeated harvests, season changes and indoor cultivation. This game retains its own characters, crops, economy, night-watering rule, painted style and upgrade ladder.

## Architecture and persistence

`FarmGrid` owns crop lifecycle state; both outdoor and indoor instances read the same `game_balance.lua` catalog. Indoor behavior is declared by the map. `FarmEquipment` owns the morning automation pass and uses WorldRoot2D's placed-item records as its single persistent record. Placement, machine loading/collection and upgrade payments use EconomyManager's atomic ownership operations. SaveManager validates both crop models, placement records and machine jobs before replacing any live owner. New fields are optional for older valid saves; their default area remains the outdoor farm.

## Art review

The 49 new sprites and icons were inspected on `painted-assets.png`, alongside native greenhouse, crop, machine and menu captures. Twelve original transparent paintings are retained under `tools/art/drawn/sources/farm_completion/`; exact built-in imagegen prompts and source hashes are in `docs/art/farm-completion/`. Packing only extracts complete disconnected plants, scales them and calibrates pivots and ground planes. No procedural repainting or color changes were used.

The greenhouse follows the established honey timber, sage, cream and muted terracotta palette. Its back-wall-only interior leaves real floor tiles, beds, characters and placed equipment visible. Seed packets are distinct from harvested crop icons. Processing products share the painted preserves-jar or juice-bottle container and retain distinct localized names and prices. Quality sprinklers share the basic sprinkler illustration and differ in name, rarity and watering range. Existing game illustrations, fitted ghost garments and city geometry remain unchanged.

The current art catalog covers 62 characters, 435 items, 29 tile sets and 396 props with no gaps. The explicit visual review snapshot covers 2,974 visual/theme assets. Automated checks establish coverage and provenance; the contact sheet and native captures provide the visual review evidence.

## Validation

Final results and source bindings are recorded in `ACCEPTANCE.json`. The aggregate regression record and accepted follow-ups supersede failing integration iterations. The original full-run report is retained with its failures visible. Native tests exercise actual held-tool input, planting/watering/sleep/shipping, both animal upgrade rounds, greenhouse door/exit movement, machine use, seed purchasing, the four-row upgrade menu and all ten home tiers. Test wrappers use disposable save directories.

Prior town proof reports and their raw evidence were archived in `prior-town-proofs/` before regenerating the canonical source-bound reports. Previous ghost/city acceptance therefore retains its historical proof evidence.

## Integration follow-up

The initial full accelerated run completed 16,824 checks across 142 sections with no unexpected engine messages. Its 15 failures identified greenhouse-era fixture counts, stale route source hashes, the F8 input contract, pause-menu layout, cheat-menu audit setup and a 301 µs location sweep against a 300 µs limit. The affected owners were rechecked after the fixes; the isolated performance sweep measured 289 µs with the limit unchanged.

The marker checks now require all four greenhouse/equipment handlers and the farm's return spawn. The graph check recognizes the conditional greenhouse door; actual entry and exit are separately exercised with player input. Town routes were rebuilt against the final farm map and prop configuration. The F8 binding accepts every keyboard device and has its own explicit contract while retaining the original 38 gameplay bindings. The pause card fits its visible actions, remains centered, and scrolls when needed. Native review covers the compact fixture and the real farm's full menu, including keyboard focus on its last row. The reviewed pause baseline includes the F8 entry. Cheat-menu audit setup preserves the phase it started in and is registered with the other screen fixtures.

`regression-coverage.json` records the latest completed result for each section, with the original full report and the affected-owner, performance and town-proof follow-ups kept as separate source reports. It is an aggregate of completed runs, not a claim that the original failing invocation was green. `ACCEPTANCE.json` records the final counts, current source binding and verification on main.

## Main acceptance

The latest section results cover 16,833 headless checks across 142 sections, with zero failed sections and 163 explicit skips retained in the reports. This is the documented aggregate of the full invocation and affected-owner reruns. All 370 native checks pass across the gameplay batch and an isolated menu-gallery run, with no skipped native checks or unexpected engine messages. The menu gallery uses a fresh disposable HOME because the farm sleep playthrough creates a real autosave; its empty-slot screenshot reference otherwise sees that saved progress. No source or reference was changed for this isolated rerun. Both original and follow-up reports are retained.

The canonical extension and eight-defect proof set pass on main at source binding `10eb7928e425e293114473c749e070f83abff074ce792a3811d5eb0ea141e54e`. The town-loop consumer passes 163 checks with zero skips. Static checks pass for all 66 CSV files / 4,540 keys, copy, import stubs and 2,974 reviewed visual/theme assets. Main greenhouse and full pause-menu captures were inspected. Implementation and integration fixes are committed; no remote push was made.
