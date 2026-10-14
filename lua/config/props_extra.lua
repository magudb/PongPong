-- config/props_extra.lua
-- Gameplay of the props that did not exist in the first art export (DATA, package P22-art-environment): the Hyggebyen buildings and street
-- furniture, the farm contract props, the three new crops, the Moerkeskoven forest set (crowns, bushes, runestone, cave ring ...) and the
-- additive decals / fx of the dungeon. The area builder reads it through GameData.prop_def(id), merged over props.lua (P04) and under
-- props_features.lua (A1): a later file overrides an earlier one key by key. The ART (png, pivot, footprint in assets/iso_props/props.json)
-- is baked by tools/art/environment; tests/sections/art_environment.gd proves that every row has art and every art has a row (and that the
-- footprint written here equals the baked one).
--
--   art        art id in assets/iso_props/props.json (default: the key itself); an alias row reuses another sprite (crown_*_solid)
--   footprint  { x, z } cells; x runs towards the screen lower-right, z towards the lower-left. The object char of a multi-cell prop
--              marks its FRONT cell (the south-most one); the art's pivot is the footprint centre.
--   solid      { shape = "circle", radius = R }    a ground-plane circle of radius R (a flattened ellipse on screen: trunk 26, rock 30)
--              { shape = "footprint", pad = P }     the footprint parallelogram padded by P ground px (buildings 20)
--              { shape = "none" }                    nothing (decals, fx, textures)
--   strips     y-sort slicing of a big sprite: > 0 cuts it into vertical strips of 32 px (at least this many), each sorted at the footprint
--              front line under that strip; 0 = one sort key at the pivot
--   interact   what E / the marker handler does with it: chest | mailbox | runestone | enemy_host | none (data for the handlers of F4, V6, D2, DR3)
--   light      { radius, color, energy, offset = { x, y } } a PointLight2D that ramps in with the night factor
--   blend      "add" = an additive soft sprite (Glow.additive_material)         texture = true: a 256 px repeating ground texture, never placed
--   unshaded   true = drawn bright on purpose (pickups, chests): the forest grade does not darken it (V8's ForestDress)
-- The ten farm-only props of N03 (trunks, shed, bin, stakes) have their rows here verbatim from design_farm.md 10.3 (their art is N03's, wave 5).
-- Lua subset: literals only, no arithmetic; lists are { a, b }.

kind = "config"

config = {
  props_extra = {
    -- ================================================================== Hyggebyen buildings (mushroom-house variants with signs)
    house_town_hall = { footprint = { 3, 3 }, solid = { shape = "footprint", pad = 20 }, strips = 16, interact = "none" },
    house_bakery = { footprint = { 2, 2 }, solid = { shape = "footprint", pad = 20 }, strips = 10, interact = "none" },
    house_seedshop = { footprint = { 2, 2 }, solid = { shape = "footprint", pad = 20 }, strips = 10, interact = "none" },
    house_smithy = { footprint = { 2, 2 }, solid = { shape = "footprint", pad = 20 }, strips = 10, interact = "none" },
    house_animalstore = { footprint = { 2, 2 }, solid = { shape = "footprint", pad = 20 }, strips = 10, interact = "none" },
    tower_wizard = { footprint = { 2, 2 }, solid = { shape = "footprint", pad = 20 }, strips = 10, interact = "none" },
    house_king_treetop = { footprint = { 3, 3 }, solid = { shape = "footprint", pad = 20 }, strips = 16, interact = "none" },

    -- street furniture and market quarter
    well = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 30 }, strips = 0, interact = "none" },
    fountain = { footprint = { 2, 2 }, solid = { shape = "circle", radius = 74 }, strips = 0, interact = "none" },
    market_stall = { footprint = { 2, 1 }, solid = { shape = "footprint", pad = 8 }, strips = 6, interact = "none" },
    market_stall_furniture = { footprint = { 2, 1 }, solid = { shape = "footprint", pad = 8 }, strips = 6, interact = "none" },
    market_stall_tailor = { footprint = { 2, 1 }, solid = { shape = "footprint", pad = 8 }, strips = 6, interact = "none" },
    plank_stack = { footprint = { 2, 1 }, solid = { shape = "footprint", pad = 6 }, strips = 0, interact = "none" },
    wheat_sack = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 16 }, strips = 0, interact = "none" },
    beehive_stand = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 22 }, strips = 0, interact = "none" },
    stone_path_a = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, interact = "none" },
    stone_path_b = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, interact = "none" },
    stone_path_c = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, interact = "none" },
    bed = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, interact = "none" },
    roof_patch = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, interact = "none" },

    -- lantern posts with the glow colours of the Hyggebyen palette (the farm keeps the honey lantern_post of props.lua)
    lantern_post_rose = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 12 }, strips = 0, interact = "none", light = { radius = 330, color = "ffb8cc", energy = 0.85, offset = { 14, -126 } } },
    lantern_post_lavender = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 12 }, strips = 0, interact = "none", light = { radius = 330, color = "d2c0ff", energy = 0.85, offset = { 14, -126 } } },
    lantern_post_mint = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 12 }, strips = 0, interact = "none", light = { radius = 330, color = "b8f0d4", energy = 0.85, offset = { 14, -126 } } },

    -- ================================================================== farm: the 16 rows of design_farm.md 10.3 (art of the first ten: N03, wave 5)
    trunk_giant_a = { footprint = { 5, 3 }, solid = { shape = "none" }, strips = 0 },
    trunk_giant_b = { footprint = { 3, 3 }, solid = { shape = "footprint", pad = 0 }, strips = 12 },
    trunk_under_a = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    trunk_under_b = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    -- mailbox_red: the V amendment wins over the farm row (circle 14): circle 20 + interact mailbox (V6's PostBox2D); baked here because farm.map uses it first
    mailbox_red = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 20 }, strips = 0, interact = "mailbox" },
    shipping_bin = { footprint = { 2, 1 }, solid = { shape = "footprint", pad = 8 }, strips = 0 },
    tool_shed = { footprint = { 2, 2 }, solid = { shape = "footprint", pad = 12 }, strips = 6 },
    bench = { footprint = { 2, 1 }, solid = { shape = "none" }, strips = 0 },
    stake_sign = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 10 }, strips = 0 },
    rope_stake_x = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    rope_stake_z = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    paw_prints = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    build_stake = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    coop_small = { footprint = { 3, 2 }, solid = { shape = "footprint", pad = 16 }, strips = 8 },
    barn_small = { footprint = { 4, 3 }, solid = { shape = "footprint", pad = 16 }, strips = 12 },
    animal_house = { footprint = { 3, 2 }, solid = { shape = "footprint", pad = 16 }, strips = 8 },
    -- the other two contract props of the farm (the farm.map and the orchard use them): a trunk-sized body, the stone gate of the forest hub
    apple_tree = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 26 }, strips = 0, group = "prop_tree" },
    signpost = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 10 }, strips = 0, interact = "none" },
    warp_gate_stone = { footprint = { 2, 1 }, solid = { shape = "none" }, strips = 0, interact = "none" },

    -- ================================================================== crops: four art stages for each of the 8 crops (FarmView draws crop_<id>_<0..3>)
    crop_turnip_0 = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    crop_turnip_1 = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    crop_turnip_2 = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    crop_turnip_3 = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    crop_carrot_0 = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    crop_carrot_1 = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    crop_carrot_2 = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    crop_carrot_3 = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    crop_pumpkin_0 = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    crop_pumpkin_1 = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    crop_pumpkin_2 = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    crop_pumpkin_3 = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    crop_moonflower_0 = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    crop_moonflower_1 = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    crop_moonflower_2 = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    crop_moonflower_3 = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    crop_strawberry_0 = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    crop_strawberry_1 = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    crop_strawberry_2 = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    crop_strawberry_3 = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    crop_sunflower_0 = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    crop_sunflower_1 = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    crop_sunflower_2 = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    crop_sunflower_3 = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    crop_catnip_0 = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    crop_catnip_1 = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    crop_catnip_2 = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    crop_catnip_3 = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    crop_glow_berry_0 = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    crop_glow_berry_1 = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    crop_glow_berry_2 = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },
    crop_glow_berry_3 = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0 },

    -- ================================================================== Moerkeskoven (DUNGEON addendum 3.3, 7.5, 8.11)
    -- rim crowns: spheres baked at 36 degrees, ground contact = sort pivot; not solid (the rim is void + canopy); S / M / L: R 170 / 230 / 300 px
    crown_s_a = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, interact = "none" },
    crown_s_b = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, interact = "none" },
    crown_m_a = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, interact = "none" },
    crown_m_b = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, interact = "none" },
    crown_l_a = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, interact = "none" },
    crown_l_b = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, interact = "none" },
    -- free-standing crowns: the same sprite, a collider circle of 130 (S) / 175 (M) ground px (0.75 x R rounded to the leaf rim the player may brush)
    crown_s_a_solid = { art = "crown_s_a", footprint = { 1, 1 }, solid = { shape = "circle", radius = 130 }, strips = 0, interact = "none" },
    crown_s_b_solid = { art = "crown_s_b", footprint = { 1, 1 }, solid = { shape = "circle", radius = 130 }, strips = 0, interact = "none" },
    crown_m_a_solid = { art = "crown_m_a", footprint = { 1, 1 }, solid = { shape = "circle", radius = 175 }, strips = 0, interact = "none" },
    crown_m_b_solid = { art = "crown_m_b", footprint = { 1, 1 }, solid = { shape = "circle", radius = 175 }, strips = 0, interact = "none" },

    -- bushes: the ambush host (eyes are the additive eyes_glow, drawn by DR3), the empty bush after the leap
    bush_eyes_a = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 56 }, strips = 0, interact = "enemy_host" },
    bush_eyes_b = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 48 }, strips = 0, interact = "enemy_host" },
    empty_bush = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 52 }, strips = 0, interact = "none" },
    eyes_glow = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, blend = "add", interact = "none" },

    -- the Hulen (way down) and the up cave: ground decals with a walkable rim; the five loose stones around them are solid
    cave_ring = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, interact = "none" },
    cave_ring_up = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, interact = "none" },
    hulen_eyes = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, blend = "add", interact = "none" },
    cave_stone = { art = "cave_stone_a", footprint = { 1, 1 }, solid = { shape = "circle", radius = 40 }, strips = 0, interact = "none" },
    cave_stone_a = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 40 }, strips = 0, interact = "none" },
    cave_stone_b = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 40 }, strips = 0, interact = "none" },
    cave_stone_c = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 40 }, strips = 0, interact = "none" },
    cave_stone_d = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 40 }, strips = 0, interact = "none" },
    cave_stone_e = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 40 }, strips = 0, interact = "none" },
    home_rope = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, interact = "none" },

    -- the runestone: a ground-plane circle is the ellipse the player walks around; the glyph is the additive rune_glow
    runestone_dormant = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 36 }, strips = 0, interact = "runestone" },
    runestone_active = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 36 }, strips = 0, interact = "runestone" },
    rune_glow = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, blend = "add", interact = "none" },

    -- the Moon pond: water is the bog_o tile plus the SoftGround decal; lily pads, one ripple animation and an additive sheen on it
    pond_lily = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, interact = "none" },
    pond_ripple = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, blend = "add", interact = "none" },
    pond_sheen = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, blend = "add", interact = "none" },

    -- seamless 256 px ground textures (SoftGround, V8) and the soft atmosphere layers
    path_tile_o = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, texture = true, interact = "none" },
    pond_water_o = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, texture = true, interact = "none" },
    floor_patch_a = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, texture = true, interact = "none" },
    floor_patch_b = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, texture = true, interact = "none" },
    floor_patch_c = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, texture = true, interact = "none" },
    mist_patch_a = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, interact = "none" },
    mist_patch_b = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, interact = "none" },
    firefly_dot = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, blend = "add", interact = "none" },
    lantern_light = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, texture = true, interact = "none" },

    -- the lake chest of floors 3 / 6 / 9 (landmark 6 of the sketch) and the farm mailbox are chests / boxes with their own interact type
    chest_noegle = { footprint = { 1, 1 }, solid = { shape = "circle", radius = 22 }, strips = 0, interact = "chest", tier = "noegle", unshaded = true },
    tornebaer = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, interact = "none", unshaded = true },

    -- the experience layer (DR0, DR3, DR4): additive ground decals, boss layers, fx sprites
    telegraph_ring_s = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, blend = "add", interact = "none" },
    telegraph_ring_m = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, blend = "add", interact = "none" },
    telegraph_ring_l = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, blend = "add", interact = "none" },
    telegraph_line = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, blend = "add", interact = "none" },
    boss_arena_ring = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, blend = "add", interact = "none" },
    halo_amber = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, blend = "add", interact = "none" },
    halo_violet = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, blend = "add", interact = "none" },
    crown_spark = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, blend = "add", interact = "none" },
    fx_hit_spark = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, blend = "add", interact = "none" },
    fx_heal_sparkle = { footprint = { 1, 1 }, solid = { shape = "none" }, strips = 0, blend = "add", interact = "none" },
  },
}
