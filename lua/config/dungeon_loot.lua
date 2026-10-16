-- config/dungeon_loot.lua (D-loot-data, wave 4): HOW the dungeon hands out loot.  WHAT exists and WHERE it is found stays in lua/data/loot_tables.lua (config key `loot`).
-- Read by LootService (F4 amended), the floor generator (loot-bearing node counts), Enemy2D and ResourceNode2D (hp curve, node yields).  Top-level key `dungeon_loot` is new.
-- The floor LAYOUT (which floor has a boss, a lake chest, how many digs and enemies, which hidden spots) is the generator's config key `dungeon` (lua/config/dungeon.lua, track generator);
-- this file only adds what is loot-specific and must agree with it: the band names (= loot zones), the boss ids, the depth ladder, the loot-bearing node budget, the appraisal and the caps.
-- Units: bp = basis points (10000 = 100 percent); sell values are gold (guldagern); floors are 1-based; "day" = GameManager.total_day().
-- Lua subset: no arithmetic, no loops, no mixed tables; lists of per-floor tables are positional (index = floor number).

kind = "config"

config = {
  dungeon_loot = {
    v = 1,
    -- The four loot zones of lua/data/loot_tables.lua are the DEPTH BANDS of the dungeon (the 367 find sources, the pools and the 23 forest keepsakes stay valid).  main_tier = the tier of the
    -- ONE ordinary chest every floor of the band carries (generator: dungeon.bands.<band>.chest_tier); rough = the unknown stone the band's crystals and chests give.
    bands = {
      skovkant = { from = 1, to = 3, main_tier = "trae", rough = "rough_skovkant" },
      dybe_bregner = { from = 4, to = 6, main_tier = "jern", rough = "rough_dybe_bregner" },
      svampelunden = { from = 7, to = 9, main_tier = "jern", rough = "rough_svampelunden" },
      krystalgrotten = { from = 10, to = 12, main_tier = "fe", rough = "rough_krystalgrotten" },
    },
    band_order = { "skovkant", "dybe_bregner", "svampelunden", "krystalgrotten" },
    -- bosses by floor = the boss list of the generator and the experience track (DX4 v2): floors 4 / 8 / 12, kinds snurresvamp, snurresvamp_gloed, snurresvamp_konge (recoloured bakes); the keys of loot.boss must equal these ids
    bosses = { { floor = 4, id = "snurresvamp" }, { floor = 8, id = "snurresvamp_gloed" }, { floor = 12, id = "snurresvamp_konge" } },

    -- Rarity odds of an ordinary roll at floor f: base odds of the container (loot.containers.<tier>.odds), uncommon x s and rare x s^2, renormalised (normal keeps x 1);
    -- s = 1 + rarity_step x (min(f, cap_floor) - 1); luck: uncommon and rare x (1 + luck_mult x L) like F4 task 2 (L = clamp(Perks.total("luck"), 0, 0.20)), normal absorbs the difference.
    depth = { rarity_step = 0.10, cap_floor = 12, luck_mult = 5 },

    -- The pace of keepsakes: at most one unique from the hunted sources (hidden spots, lake chests, wanderers) per `cooldown_days` days.  While the cooldown runs LootService.pending_spots() hides
    -- the spots (the generator does not place them) and a wanderer / lake keepsake waits for the next opening; bosses (first kill, pool) and quests are never delayed.
    unique = { cooldown_days = 7 },

    -- Daily value cap (anti-farming): gold-equivalent SELL value of the RARITY-RESTRICTED finds the dungeon handed out on one day (days are paused inside the dungeon, so this is "per day, however many runs").
    -- `counts` = the sources that burn the cap: ordinary / lake / boss chests, digs and appraised gems (the only sources whose rarity the cap can restrict); nodes, creature drops and surprise gold do NOT count
    -- (they cannot hand out rare items, and counting them burned the cap by floor 7-9 of a clear-all day, which defeated "deeper floors drop better rarities").  Counted when a plan is COMMITTED (a plan
    -- that does not fit the backpack counts nothing).  When the cap is reached the rest of the day's ORDINARY rolls cap the rarity at uncommon and draw only these kinds; the whisper is shown once.
    -- Keepsakes, boss pools, first kills and quest items are never counted or capped.  Measured (final_candidate/final_sim/results/16_cap_grid_final.txt, clear-all day from floor 1, dust at its real price):
    -- cap 3200 -> P(cap reached before floor 10) 5 % at luck 0 and 20 % at luck 0.2, rare items on floors 10-12 79 % / 48 % of the uncapped day, net gold 2 149 / 2 847 (48 / 64 gold per minute of a 44.5 minute dive).
    daily = { value_cap = 3200, counts = { "chest", "dig", "appraise" }, rarity_cap = "uncommon", kinds = { material = 70, gem = 30 }, whisper_key = "LOOT_DAY_TIRED" },

    -- NOTE (merged addendum, decision DX30): there is NO per-floor budget of loot-bearing crystals any more.  Every crystal node the generator places (art kinds amethyst, emerald, moonstone,
    -- crystal_shard: 45 per full dive, `dungeon.floors[].nodes`) is the loot kind `crystal` (colour is art only) and gives SOMETHING every time: the band's unknown stone with chance_bp, else one glimmer dust.
    -- Measured (final_candidate/final_sim, loot_mc.py with this data, the dng_* surplus sold at its real price, cap 3200 on the restricted sources): typical castle day 246 (keep) / 220 (sell), full dive 2,409 gold uncapped / 2,205 capped (luck 0).
    -- (steel_vein, moon_vein, resin_tree, slate_vein, marble_vein of the loot track's first draft are DELETED: the generator places none of them; the materials come from chests, drops and the crystal extras.)
    -- What ONE node of a kind hands out (rolled by LootService.node_loot(kind, uid, ctx) with the node's uid, never by the node's own RNG).  Kinds are the node ids of the generator's lists; `alias` = same yield as another row; `fallback` = what a failed chance_bp roll gives (a harvest never gives nothing).
    node_yields = {
      moss_patch = { item = "moss", amount = { 1, 2 } },
      glow_mushroom = { item = "glow_mushroom", amount = { 1, 2 } },
      tree_chop = { item = "wood", amount = { 2, 4 } },
      iron_ore = { item = "iron_ore", amount = { 1, 1 } },
      copper_ore = { item = "copper_ore", amount = { 1, 1 } },
      gold_ore = { item = "gold_ore", amount = { 1, 1 } },
      rock_stone = { item = "stone", amount = { 2, 3 } },
      fern = { item = "fern", amount = { 1, 2 } },
      rare_mushroom = { item = "rare_mushroom", amount = { 1, 1 }, chance_bp = 5000 },
      night_bloom = { item = "night_bloom", amount = { 1, 1 } },
      amethyst = { alias = "crystal" },
      emerald = { alias = "crystal" },
      moonstone = { alias = "crystal" },
      crystal_shard = { alias = "crystal" },
      crystal = { rough = true, chance_bp = 3000, fallback = { item = "dng_glimmer_dust", amount = { 1, 1 } }, extra = { { item = "dng_glimmer_dust", bp = 3000, bands = { "svampelunden", "krystalgrotten" } }, { item = "dng_crystal_root", bp = 700, bands = { "krystalgrotten" } } } },
    },
    -- Creature drops (LootService.on_enemy_defeated(kind, ctx)); the loot.creatures find_chance rolls stay.  bp per kill.
    drops = {
      bat = { { item = "moss", bp = 1800, amount = { 1, 2 } }, { item = "dng_resin", bp = 600, amount = { 1, 1 } } },
      ugleoje = { { item = "dng_owl_feather", bp = 1400, amount = { 1, 1 } }, { item = "moss", bp = 800, amount = { 1, 2 } } },
      tornebusk = { { item = "dng_forest_thread", bp = 1800, amount = { 1, 2 } }, { item = "wood", bp = 1300, amount = { 1, 2 } } },
      lysesvamp = { { item = "glow_mushroom", bp = 2100, amount = { 1, 2 } }, { item = "dng_mushroom_felt", bp = 1000, amount = { 1, 1 } } },
      -- optional kinds (experience R-G6 / R-L2): only used when the generator mixes them in
      mosfroe = { { item = "fern", bp = 1800, amount = { 1, 2 } }, { item = "moss", bp = 1500, amount = { 1, 2 } } },
      sporesvamp = { { item = "glow_mushroom", bp = 3000, amount = { 2, 2 } } },
      krystalugle = { { item = "crystal_shard", bp = 1500, amount = { 1, 1 } }, { item = "dng_glimmer_dust", bp = 800, amount = { 1, 1 } } },
    },

    -- Cozy surprises (never a trap, never a mimic): one independent roll per opened ORDINARY chest; LootService hands the winner to the experience layer as game_event dungeon_surprise { id, ... }.
    -- firefly_swarm = lantern oil, acorn_purse = gold, cocoa_thermos = hearts, pip_note = a whisper that hints at a hidden spot of the band (the hunter's bad-luck protection).
    surprises = {
      { id = "firefly_swarm", bp = 120, oil_s = 15 },
      { id = "acorn_purse", bp = 100, gold = { 15, 40 } },
      { id = "cocoa_thermos", bp = 80, heal_half_hearts = 2 },
      { id = "pip_note", bp = 60, hint = "spot" },
    },

    -- Fru Ugle (npc appraiser_fru_ugle): appraise(rough_<band>) turns ONE rough stone into one cut gem for the fee.  The outcome is a pure function of (world seed, band, the BAND'S OWN appraisal counter n_band):
    -- the draw is keyed rng_keyed("appraise:" .. band, n_band), so a result of one band says nothing about another band, and LootService.appraise() commits the counter and the stone count with
    -- SaveManager.autosave() before the result is shown (a quit cannot take it back).  Corrected net per stone (fee against the sell value of the cut gem, uncommon and rare x (1 + 5 L) clamped to 100 %):
    -- luck 0: +15 / +15 / +7 / 0 (skovkant .. krystalgrotten); luck 0.2: +37 / +48 / +35 / +20 (final_candidate/final_sim/results/04_appraisal_ev_fixed.txt).
    -- Rarity by odds[band] (uncommon and rare x luck), gem by pools[rarity] weights.  No unique or legendary gem comes from here (they have fixed sources: lake chests and bosses).
    appraisal = {
      fee = { skovkant = 30, dybe_bregner = 50, svampelunden = 75, krystalgrotten = 105 },
      odds = {
        skovkant = { normal = 6400, uncommon = 3300, rare = 300 },
        dybe_bregner = { normal = 4500, uncommon = 4500, rare = 1000 },
        svampelunden = { normal = 3200, uncommon = 5000, rare = 1800 },
        krystalgrotten = { normal = 2000, uncommon = 5000, rare = 3000 },
      },
      pools = {
        normal = { { item = "gem_rock_crystal", w = 10 }, { item = "gem_smoky_quartz", w = 10 }, { item = "gem_moss_agate", w = 10 }, { item = "gem_forest_jade", w = 10 } },
        uncommon = { { item = "amethyst", w = 10 }, { item = "amber", w = 10 }, { item = "rose_quartz", w = 10 }, { item = "crystal_shard", w = 10 }, { item = "gem_thornberry_stone", w = 10 }, { item = "gem_mushroom_opal", w = 10 } },
        rare = { { item = "moonstone", w = 8 }, { item = "emerald", w = 10 }, { item = "gem_night_sapphire", w = 10 }, { item = "gem_fairy_tear", w = 10 } },
      },
      batch_max = 12,
    },

    -- Hard limits of the perks (weapon effects, lantern gem, species perk never stack past these): the fairy light cooldown never drops below light_cd_min_s (base 7 s, experience DE: race_perks.lua:63-84);
    -- chest sense is the MAX of its sources (monkey perk 12, spear of the roots 12, emerald / legendary gems), never their sum.
    -- recipe_unbuyable_mult / material_sell_max_pct: the ONE valuation rule of validator W5 and check dungeon_items.recipes_in_cost_band (an ingredient with buy_price 0 is valued at recipe_unbuyable_mult x its sell_price;
    -- every dng_ material sells for at most material_sell_max_pct percent of its nominal buy_price: validator M2).
    limits = { light_cd_min_s = 3.0, chest_sense_max_cells = 12, recipe_unbuyable_mult = 2.2, material_sell_max_pct = 25 },

    -- The lantern gem (equipment slot `accessory`): ONE gem in the lantern.  A gem def carries lantern = { tint, themes[] }; every theme gives unit x step(rarity) (normal = colour only).
    -- Units: oil / radius = fraction, light_cd = seconds, chest_sense = CELLS (a legendary gem = 12 cells = the monkey Kiki's species perk), ambush = fraction of the bush-eyes pulse distance (780 px, experience DE14), pickup = fraction of the pickup magnet radius.
    lantern_gem = {
      unit = { oil = 0.04, radius = 0.04, light_cd = 0.5, chest_sense = 3, ambush = 0.2, pickup = 0.2 },
      steps = { normal = 0, uncommon = 1, rare = 2, unique = 3, legendary = 4 },
      existing = {
        crystal_shard = { tint = "a9d3e0", themes = { "radius" } },
        rose_quartz = { tint = "f2a7b8", themes = { "pickup" } },
        amber = { tint = "e8b04a", themes = { "oil" } },
        amethyst = { tint = "9b86d6", themes = { "light_cd" } },
        moonstone = { tint = "cfd6f2", themes = { "ambush" } },
        emerald = { tint = "5fbf8a", themes = { "chest_sense" } },
      },
    },
  },
}
