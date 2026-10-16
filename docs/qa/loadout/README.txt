Wardrobe and loadout acceptance

G or Pause > Wardrobe opens Clothes and Hands. Try on, Equip and Remove are
separate actions. Work / Forest / Festival save worn clothing. Hands changes
existing weapon/tool equipment and the existing eight-slot hotbar. Actual game
state and clothing persist through Save / Continue. New games can immediately
switch between the supplied shirt/trousers and cream dress.

Feature source: 2e6035e. Final scroll/focus and empty-state correction: 27b66d7.
Art: assets/wardrobe/manifest.json; exact prompts: docs/art/wardrobe/prompts.json.
Production ownership, fitting and shader details: docs/art/wardrobe/design.txt.

Evidence

regression.json: 1,864 checks across wardrobe, player, economy, loot, save,
characters, content, Secret Garden, UI and walkway transitions; no failures or
unexpected engine messages. Intentional save-failure controls retain 16 named
allowed messages, and 78 capability/window checks are explicitly skipped.

animal/fairy/hobbit/ghost.json: 94 headless checks per race; native-<race>.json:
98 native checks per race, each covering both heroes of that race. These cover
wardrobe UI, all body poses and held equipment. Final UI scroll changes have
additional dedicated ui-final / native-ui-final and native-ui-<race> reports.

Native catalog pages render all 96 palettes on fox and all 30 garment families
on each of the other seven bodies. catalog_<body>.json records item IDs and
measured face visibility. turnarounds_<body>.png contains three mixed outfits
in S, SW, W, NW, N, NE, E, SE order. All seven simultaneous slots, dresses,
hoods, wizard hats, circlets, hands, tails, fairy wings, braids, hobbit toes and
ghost hems were reviewed. Stock animations and portraits are unchanged. These
captures and the frame/region alignment checks do not constitute a per-pixel
review of every stock animation frame. native-<race>/ also contains real Clothes,
Hands, world/tool and forest/weapon captures.

native-budgets.json preserves the existing town budgets, including all seven
worn layers in the city crowd and the existing <=16 total equipment draw
increment. Full frame-time and memory measurements include clothing. The
original <=250 city/HUD baseline is measured with all equipment hidden; no
budgets were raised. Native frame/memory results are on Apple M3, macOS,
Godot 4.7.2, Compatibility GL 4.1 / Metal 90.5, from the source project.

acceptance.json records final results, source binding and artifact hashes.
Extension and producer-mutant proofs are renewed for the current implementation.
The held-equipment feature's previous 8f39a661 proofs and raw controls were
archived under ../held-equipment/source-proof-8f39a661/ before refreshing the
live town proofs. Its acceptance now points to that archive.

All 2,815 approved visual/theme assets match the style ledger: 2,563 existing
assets retained their exact bytes, and 252 wardrobe rasters have explicit new
visual dispositions (240 clothing fits, four safe bases, eight technical masks).
New da/en copy remains draft and unvoiced. Import, copy, CSV and voice checks
are saved alongside acceptance. The five older da.csv issues remain named
legacy findings. This feature does not include packaged-export measurements.

Reproduce

  tests/run_playtest.sh --fast --strict --no-boot \
    --only=wardrobe,wardrobe_ui,wardrobe_render,held_equipment,player,ui_conformance
  tools/dev/run_windowed.sh --strict --no-boot --character=fairy \
    --only=wardrobe_ui,wardrobe_render,held_equipment --out=/tmp/wardrobe-fairy
  tools/dev/run_windowed.sh --strict --no-boot --only=town_budgets,ui_conformance
  tools/art/.venv/bin/python tools/art/drawn/style_audit_current.py --check
  python3 tools/town/prove_extension.py --check
  python3 tools/town/prove_mutants.py --check

The development directory retains superseded authoring captures and failures.
Only the named final reports and captures are acceptance evidence.
