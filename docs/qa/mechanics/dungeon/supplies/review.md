# Dungeon supplies

Five existing live items had fallback pictures: the floor map, light drop, mushroom elixir, thornberries and owl key. Each now has its own painted transparent icon, matching the approved resource and food sheets used as style references.

All five source paintings and both native day/night UI captures were opened and inspected at 112 and 64 pixel display sizes. The folded room plan differs from Mother’s stitched route map. Amber and lavender bottles, the bramble cluster and the owl-shaped key remain distinguishable at the smaller size. Normal rarity uses the existing cream slot and ink border; no rarity colour is baked into the paintings.

`native.json` records 21 passing source, alpha, size, byte-budget and runtime-resolution checks with no engine messages. The strict effective catalog also resolves all five items. `make_supplies.py --check` reproduces the five lossless WebP exports from their saved sources and verifies import settings.

Exact prompts and input roles are saved in `docs/art/dungeon-loadout/supply-icon-prompts.json`, with raw imagegen origins in the adjacent generation record. Manufacturing only trims alpha and scales uniformly to fit the existing 128 pixel canvas. The review ledger adds these five icons and four story props after confirming all 2,895 prior approved visual/theme assets retain identical bytes.
