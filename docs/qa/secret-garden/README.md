# Secret Garden validation

The playable garden restores a communal place through twelve objectives and introduces the first evidence in the missing-mother story. Source implementation: `1028b49`. Design and playing instructions: [Secret Garden addendum](../../design/SECRET_GARDEN_ADDENDUM.md).

[Restored garden](native/secret_garden_restored.png) · [Overgrown garden](native/secret_garden_overgrown.png) · [Pip’s account](native/secret_garden_post_account.png) · [Town entrance](native/secret_garden_town_entrance.png).

## Journey and regression coverage

`animal.json`, `fairy.json`, `hobbit.json` and `ghost.json` each contain 124 passing checks. Each run completes the entire journey for both skins of its race: all eight heroes, 496 checks total, no skips or engine messages. The fixture uses production quest, dialogue, interaction, travel and save systems. It exercises cancellation, area departure during dialogue, parked-area re-entry, four beds reachable with an inflated player body, ordering, a real overnight wait, saved watering date, save/load before and after completion, evidence gates, one-time rewards, family branching, rereading and physical walk-throughs of both garden gates. NPC interaction uses real scheduled actors and topic buttons. Inter-area setup uses the normal world entry method; this is not an uninterrupted manual walk of the whole world.

`regression.json` contains 810 passing checks across the garden, quests, social talk, ghost-family data, map geometry, town routes and boardwalk/stair transitions. Seven pre-existing capability skips remain: three deferred forest marker handlers, the generated forest-floor return, FurnitureManager, a generated mushroom completer and dungeon anchor placement. The new garden quest receives strict quest metadata checks and adds no skip. `routes-bake.json` records a successful fresh navigation bake and its 104 checks.

`regression-arrival-overlap.json` preserves the earlier failing arrival probe. It caught the garden return inside the king’s padded footprint. The final entrance is beside the seed shop, with its return outside both house collision and the warp trigger. Every town spawn must reach both exits; the old bridge geometry and real bridge walk remain checked.

`native.json` records 63 passing checks at 1280×720 on Godot 4.7.2, Compatibility/OpenGL, Apple M3. Six original screenshots and their hashes are in `native/`. The restored view shows the final four beds, watered soil, bench, planted boundary and clear paths. The dialogue capture verifies the new text in the existing parchment panel. Screenshots can retain ordinary arrival, quest and save notifications; the restored view waits for them to expire. Both physical gate transitions pass in the native window.

## Art, copy and scope

All 2,562 approved visual/theme assets retain their bytes and reviewed dispositions (`static-style.txt`). This feature places existing paintings; it generates no replacement paintings. Import stubs pass (`static-imports.txt`). Strict copy lint passes for all three changed localization files (`static-copy.json`). The social voice index remains in sync and all ten frozen family voice rows are unchanged in both languages (`static-voice.txt`). New copy remains draft and unrecorded.

`static-localization.json` and `static-localization-baseline.json` show the same five legacy findings in `da.csv`: three duplicate keys and two malformed rows. The ordinary localization lint passes with those reported; its global strict mode still fails on that pre-existing set. No new localization finding was introduced.

The initial `core.json` is an earlier baseline check of the unchanged core managers; its six explicitly expected negative-control messages are recorded in that report. Final town proofs, performance gates and merged-main verification are indexed by `acceptance.json`.

The deeper Dark Forest chapters S03–S08 and the mother’s final fate remain proposed content. Garden completion supplies the introductory clues and the garden’s own conclusion. Native checks run the source project; no packaged export or audio-recording acceptance is claimed.

## Town proofs and native timing variability

All 36 required wave-5b gates pass in `gates.json`, with 159 passing headless town integration/budget checks. The freshly bound data-only extension has 588 owner checks and eight scenarios; all seven producer mutations are caught after a clean baseline. Live proofs use the final garden source binding. The boardwalk acceptance keeps its earlier proofs under `../walkway-transitions/source-proof-cd7ed9e9/`.

The two full native town attempts have timing failures and are preserved, rather than presented as fully green runs. `native-towns.json` passes all 27 rendering/resource budget checks but its town save p95 is 43.802 ms against 25 ms. Its crowd render is 3.129 ms against 6 ms. The unchanged isolated loop retry (`native-towns-retry.json`) passes the save check at 21.988 ms but samples a city frame at 8.088 ms. Both loops complete their 110-second budget and all functional checks pass.

The existing isolated rendering fixture then passes on both unchanged main (`native-fixtures-baseline.json`, 3.092 ms) and the garden commit (`native-fixtures-current.json`, 3.165 ms), with the same 6 ms threshold. This comparison does not establish the cause of the earlier timing variation. No budgets were relaxed, and neither the production save code nor the city renderer was changed. The retry omitted the wave environment; the strict headless integration independently enforces all required gates. Raw logs, reports and capture hashes retain these distinctions.

## Merged main

The implementation and evidence were fast-forwarded into local `main`. `merged-main.json` records 397 passing checks of core, the full two-skin garden journey, town loop and budgets. Eleven existing town capability skips and seven explicit negative-control messages remain; there are no unexpected engine messages. `merged-gates.json` passes all 36 required wave-5b gates, and both source-bound proofs still match. `merge-verification.json` records the tested head, matching source bindings and ancestry of every finished worktree. The following commit contains QA documentation only.
