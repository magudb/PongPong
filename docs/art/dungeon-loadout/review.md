# Painted dungeon weapons

The 22 new weapon IDs now use separate painted objects rather than an invisible attachment or a shared sword. Each has eight physical directional views. Daggers, swords, clubs, spears and staffs retain their family silhouettes and the materials described by their item text. Inventory icons use the same source as the held item. Four legendary icons have the established pale technical rim.

Generation used the built-in imagegen tool. Exact requests and reference roles are in `weapon-prompts.json`; selected source paths and generation outputs are in `generation-record.json`. The source paintings are saved under `tools/art/drawn/sources/dungeon_weapons/`. The Bee Sting extraction attempt is unselected: inspection established the original already had transparent gutters, so the original, more matte painting is retained.

I inspected every generated sheet and all 176 views on the packed grip contact sheet. The inspected native catalog shows all 22 new items beside the fox and their matching readouts. Native fox/monkey interaction and save/load checks pass. The ghost, fairy and hobbit runs cover their paired heroes and reuse the existing body-specific animation sockets. This does not claim a new pixel-by-pixel review of every animation frame.

The legendary day/night card capture was opened and reviewed for the moon sword, trunk club, root spear and star staff. The source contours and materials remain visible on both parchment and the night panel; rarity keeps its separate ring and pips. Dark-background labels use the existing per-control color override.

`make_weapons.py` only trims alpha, contains the paintings without stretching, packs atlases, exports matching icons and manufactures the technical night rim. It does not draw or recolor illustrations. It records explicit grips for each view and retains original stock textures and body sockets. Its check preserves Godot's import metadata while verifying the required preset.

Validation is in `docs/qa/mechanics/dungeon/weapons/`: 117 asset checks, the full held-equipment section for all eight heroes, a native catalog/contact sheet and native legendary cards. The style ledger adds 48 reviewed visual assets; all 2,815 previously approved visual/theme assets remain byte-identical.

The remaining rough-stone, gem and material icons are still pending. They have not been marked as complete by this weapon checkpoint.
