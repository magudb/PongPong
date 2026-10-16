Held tools and weapons

Scope: visible carried objects and a clear current-item readout, for all eight
playable heroes. See ../../art/held-equipment/review.txt for the art review and
../../art/held-equipment/prompts.json for exact built-in generation/edit prompts.

Reports

regression.json: player, equipment, Secret Garden, UI foundation/navigation/style
and walkway transitions. 741 checks, zero failures, 68 existing capability skips,
zero engine errors/warnings.

animal/fairy/hobbit/ghost.json: 42 strict headless checks each, covering primary
and alternate skin. Native counterparts use the same assertions with actual
1280x720 windowed rendering. All pass without skips or engine messages.

The fixture traverses every fitted body frame/direction, all 12 dedicated object
views, actual hoe use, changing selection during use, sword damage matching the
selected sword, changing equipment during a swing, dialogue put-away, real forest
entry, empty gear, language change and save/load into a rebuilt world.

Native images

native-<race>/held_equipment_tool_<body>.png and weapon_<body>.png are the full
native farm/forest captures, two per hero. all-heroes-contact.png contains exact
pixel crops of each hero and HUD. native-animal/catalog-contact.png contains
the actual renderer's 12 tool/weapon appearances and corresponding readouts.
stock-grips-contact.png and stock-grips-grid.png are authoring references for
the body contact points, not alternative body assets.

Town checks

native-town.json and native-town/ retain the focused real-renderer city/HUD,
shop and guide fixtures. native-budgets.json retains the native resource gates.
town-integration.json and gates.json retain the strict wave 5b town loop and all
36 required gates. The source-bound extension and producer-mutant evidence is
referenced in acceptance.json. Mutant fixture failures are intentional negative
controls; the top-level proof passes only when all seven mutations are caught.

Static checks

Changed HUD copy passes strict lint. The normal localization scan reports five
unchanged legacy findings in da.csv (three duplicates and two malformed rows).
Imports, frozen voice index, explicit visual dispositions and whitespace pass.
New Danish/English HUD rows are draft and unvoiced.

No exported-build claim is made. Prior full native town timing misses remain
documented in ../secret-garden/acceptance.json; this feature uses the focused
native render/resource probes plus the strict headless town integration.
