Ghost outfits, Treetop City movement and testing tools

Implemented on `codex-ghost-city-tools` from main `dc64592`.

Ghost shirts and dresses now use paintings shaped for the entire flowing wisp. Rear directions have back panels and strap joins. Trousers become a draped under-hem sash; footwear becomes two small hanging charms, packed separately at their original proportions. The renderer uses those registered shapes directly and calibrates dye colours against their actual source pigments. Hats, clothes and shoes keep their independent slots. The original character paintings, faces, hands, animation clock and the other six bodies retain their existing asset bytes. Thirty ghost clothing atlases changed. Exact prompts, reference roles and selected source paintings are in `docs/art/ghost-city-review/` and `tools/art/drawn/sources/wardrobe/ghost-drape/`.

Treetop City had a draw-order handoff at bridge mouths: the next deck could draw over a character before their feet changed collision levels. Rendering now anticipates the connected mouth while collision stays on its actual deck. Shadows follow that draw rank. The tracker resolves movement after the player/NPC physics update, and visual handoffs do not emit false logical level-change events. Independent native controls restore the legacy rank and hide floors: the legacy rank reproduces the overlap at all 18 mouths; the fixed face patches remain visible and match the floor-hidden controls. All nine bridges were walked both ways with real player input. The stairs were exercised up and down. All eight platforms have body-sized clear test landings; the kitchen landing avoids its planters.

F8 and Pause → Cheat menu open a normal modal with keyboard/controller focus, translated Danish/English copy and the existing parchment theme. It offers recovery, gold, searchable item grants, all clothing, the wardrobe, area/platform travel, hour/day advancement, a session clock freeze and weather. Economy, wardrobe, world travel and calendar owners perform the changes. The menu closes before travel and refuses to open over story scenes. F8 also closes while the search field has focus. Clock freeze resets on load/new game. The pause list scrolls so its additional action fits without smaller text.

The UI audit now checks validity before asking the type of old controls after a tab replaces its children. Two old framework hash assertions were updated to the already merged source bytes from earlier owner changes (`5311ccf`, `b01f89f`); those framework files were not changed here. Oak's rendering assertion now expects the connected bridge mouth rank while his collision level remains the post platform.

Clean validation evidence:

| Report | Scope | Result |
| --- | --- | --- |
| `accepted-native.json` | Five native sections: menu, UI navigation, depth controls, city walkthrough and ghost clothing | 126 checks; no failures, skips or engine messages |
| `depth.json` | Stronger native pixel checks at all 18 mouths, including actual visible head colour | 37 checks; all pass; floor-hidden face difference 0.00000 |
| `palettes.json` | All 96 variants on each ghost, mixed outfits in eight directions and every walking frame with a held sword | 16 checks; 192 catalogue cases; face difference 0.0 |
| `final-regression.json` | Art consistency, cheats, city levels/map/walkthrough and clock/calendar | 351 checks; no failures, skips or engine messages |

The moving 20-actor tracker remains within its existing 0.2 ms budget; the regression measured a best tick of 0.115 ms. Ghost tailoring remains within the existing 0.3 ms pose budget. No budget was relaxed. The clock regression simulates many days and took about 194 seconds; it passed.

The source-bound town extension and mutation proofs are refreshed in `docs/qa/m1b-milestone/`. The extension exercises production geometry, NPC routes, shops, dialogue, social rules, doors and mailbox quest offers with 584 owner checks. Earlier reports bound to `9851c7d...` are preserved in `source-proof-9851c7d/`. Superseded development captures are outside the repository in `/tmp/ghost-city-development-20261017/`.

Visual review artifacts: `ghost-outfits-before-after.png`, `city-depth-comparison.png`, the two ghost turnaround/walking sheets and all sixteen full catalogue pages under `palettes/`, plus the native city/stair and menu captures under `accepted/`. The review covers the new clothing's idle turnarounds and walking; it is not a new frame-by-frame approval of every original stock animation clip.
