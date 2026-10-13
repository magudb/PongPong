-- config/props.lua
-- Gameplay of the world props (DATA, package P04): map files choose a prop by its ART id (`@prop T tree_oak_farm`), this table says
-- what that prop DOES. The area builder (IsoArea) reads it through GameData.prop_def(id), merged with props_extra.lua (P22, the
-- blueprint props that did not exist in the first art export) and props_features.lua (A1, chests / glimmers / tent / veins); a later
-- file overrides an earlier one key by key. The art itself (png, pivot, footprint in the manifest) lives in assets/iso_props.
--
--   art        art id in assets/iso_props/*/props.json (default: the key itself)
--   footprint  { x, z } cells; x runs towards the screen lower-right, z towards the lower-left. The object char of a multi-cell prop
--              marks its FRONT cell (the south-most one); the art's pivot is the footprint centre.
--   solid      what blocks walkers (world layer):
--                { shape = "circle", radius = R }       a flattened ellipse of ground radius R (trunk 26, rock 30)
--                { shape = "footprint", pad = P }       the footprint parallelogram padded by P ground px (houses 20)
--                { shape = "bar", along = "x"|"z", length = L, width = W }   a thin barrier along a cell axis (fences)
--                { shape = "none" }                      nothing (bushes, bridge pieces, skirts)
--   strips     y-sort slicing for big sprites: > 0 cuts the sprite into vertical strips of 32 px (never fewer than this many),
--              each sorted at the footprint front line under that strip (R.10); 0 = one sort key at the pivot
--   group      extra node group of the placed sprite (prop_tree ...)
--   glow       true = a placeholder prop gets a halo too; real art carries its glow in props.json
--   light      { radius, color, energy, offset = { x, y } } a PointLight2D that ramps in with the night factor
-- Lua subset: literals only, no arithmetic; lists are { a, b }.

kind = "config"

config = {
  props = {
    -- trees (trunk = circle 26)
    tree_oak_farm = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 26 }, strips = 0, group = "prop_tree" },
    tree_oak_farm_b = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 26 }, strips = 0, group = "prop_tree" },
    tree_blossom_hyggebyen = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 26 }, strips = 0, group = "prop_tree" },
    tree_pine_forest = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 22 }, strips = 0, group = "prop_tree" },
    tree_pine_forest_b = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 22 }, strips = 0, group = "prop_tree" },
    tree_twisted = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 26 }, strips = 0, group = "prop_tree" },
    tree_giant_crown = { footprint = { 9, 9 }, solid = { shape = "footprint", pad = 0 }, strips = 70, group = "prop_tree" },

    -- bushes (walk through them)
    bush_farm = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    bush_berry = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    bush_forest = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },

    -- rocks (circle 30)
    rock_grey = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 30 }, strips = 0 },
    rock_mossy = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 30 }, strips = 0 },
    rock_dark = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 26 }, strips = 0 },

    -- ore, crystals and glow mushrooms are resource nodes (their body and hits belong to P19): the art entry alone
    ore_iron = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    ore_gold = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    ore_copper = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    crystal_amethyst = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    crystal_moonstone = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    crystal_emerald = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    glowmush_teal = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    glowmush_pink = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    glowmush_blue = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },

    -- fences: a thin barrier along the cell axis (a cell step is about 90 ground px)
    fence_x = { footprint = { 1, 1 }, solid = { shape = "bar", along = "x", length = 92, width = 10 }, strips = 0 },
    fence_z = { footprint = { 1, 1 }, solid = { shape = "bar", along = "z", length = 92, width = 10 }, strips = 0 },
    fence_gate_x = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },

    scarecrow = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 16 }, strips = 0 },

    -- bridge pieces: walkable, carried by the plank cells ('=' ground char) of a map
    bridge_x = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    bridge_z = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },

    lantern_post = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 12 }, strips = 0, light = { radius = 330, color = "ffd98a", energy = 0.85, offset = { 14, -126 } } },
    lantern_hand = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },

    chest_closed = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 24 }, strips = 0 },
    chest_open = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 24 }, strips = 0 },

    -- buildings: the footprint polygon padded by 20, sliced into 32 px strips so the side faces sort correctly
    house_farm = { footprint = { 3, 2 }, solid = { shape = "footprint", pad = 20 }, strips = 14 },
    house_mushroom_rose = { footprint = { 2, 2 }, solid = { shape = "footprint", pad = 20 }, strips = 10 },
    house_mushroom_lavender = { footprint = { 2, 2 }, solid = { shape = "footprint", pad = 20 }, strips = 10 },
    house_mushroom_mint = { footprint = { 2, 2 }, solid = { shape = "footprint", pad = 20 }, strips = 10 },

    -- platform skirts: one per edge cell, placed by the builder (never by a map char)
    platform_sw = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    platform_se = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    platform_corner = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },

    -- the props the built-in markers need until P22 ships them (props_extra.lua then overrides these entries)
    signpost = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 10 }, strips = 0 },
    warp_gate_stone = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },

    -- ortho walls of the forest and the cave (solid ground tiles, not nodes; see AreaTileSet.wall_source_for)
    forest_wall_a = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    forest_wall_b = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    forest_wall_c = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    cave_wall_a = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    cave_wall_b = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
  },
}
