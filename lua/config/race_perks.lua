-- config/race_perks.lua
-- Race perks and combat tuning as DATA (D14): game code only reads numbers/flags, designers change them here.
-- Top-level tables of this file: race_perks, combat.  Read with LuaRuntime.get_config("race_perks.<race>.<key>") /
-- get_config("combat.<key>") (GameData.perk / GameData.combat in P04).  Race ids: animal fairy hobbit ghost
-- (GameManager.CharacterType 0 1 2 3).
--
-- UNITS (plan 3.13): distances and speeds are GROUND px; the sprites are unscaled now, so every distance and speed is the
-- 3D/spike value x 1/0.6 (swing_radius 118 -> 197, dodge_distance 190 -> 317, light_radius 330 -> 550, knockback 260 -> 433).
-- Timings (seconds) are unchanged.  Every race defines EVERY perk key (neutral value when the race has no such perk), so
-- code never has to guess a default.
--
-- `species` = the CHIP list of the race (two per race since the Figurer v2 heroes; the animal chips are the ids of the species row of
-- lua/config/characters.lua), `skins` = EVERY skin id of the race in lua/config/characters.lua, retired rows included (a test keeps
-- the two lists equal).  A skin may override single perks (lua/config/species_perks.lua, read only through SpeciesPerks.value).
-- The eight keys at the end of every race (run_cost_mult ... glow_color) are the ghost's perk layer; they are neutral elsewhere.

kind = "config"

config = {
  race_perks = {
    -- Forest animal (Skovdyr): strong paws, digs faster and gets more from the harvest (copy: CHAR_ANIMAL_PERK).
    animal = {
      species = { "fox", "monkey" },    -- the two hero chips (Rasmus the fox = the race baseline, Kiki the monkey)
      skins = { "animal_fox", "animal_monkey", "animal_rabbit", "animal_hedgehog", "animal_squirrel" },   -- skin ids of lua/config/characters.lua (the last three are retired)
      default_skin = "animal_fox",
      dig_speed = 1.3,               -- till/chop animations play 30% faster
      tool_cost_mult = 0.75,         -- tool stamina cost x 0.75
      harvest_bonus_chance = 0.2,    -- chance of +1 crop on every harvest
      can_fly = false,
      flight_max_seconds = 0,        -- flight keys only matter when can_fly is true
      flight_energy_per_second = 0,
      talks_to_flowers = false,
      shop_discount = 0.0,           -- fraction off every shop price (part of Perks.total("discount"))
      bake_bonus = 0.0,              -- extra output chance in the crafting category bake
      run_cost_mult = 1.0,           -- running energy cost x this (ghost 0.6)
      oil_use_mult = 1.0,            -- lantern oil drain x this in Moerkeskoven (ghost 0.75)
      dark_light_mult = 1.0,         -- lantern light radius x this in Moerkeskoven (ghost 1.25)
      float_bob_px = 0.0,            -- a hovering figure bobs this many px around its baked hover (ghost 2.5)
      glow_energy = 0.0,             -- own PointLight2D energy at full night in iso areas (ghost 0.35)
      glow_energy_dark = 0.0,        -- the same in a dark preset (forest, cave); the lantern is E 0.10 (ghost 0.08)
      glow_scale = 0.0,              -- PointLight2D texture_scale, 1 = radius 128 px (ghost 0.9)
      glow_color = "",               -- hex (ghost "bfe0ff")
    },
    -- Fairy (Fe): can fly briefly over the fields and talks to flowers (copy: CHAR_FAIRY_PERK).
    fairy = {
      species = { "meadow", "birk" },    -- the two hero chips (Kløvermynte, Birk)
      skins = { "fairy_meadow", "fairy_birk", "fairy_stardust", "fairy_dusk" },   -- the last two are retired
      default_skin = "fairy_meadow",
      dig_speed = 1.0,
      tool_cost_mult = 1.0,
      harvest_bonus_chance = 0.0,
      can_fly = true,                -- key F toggles flight where the area allows it (@flight true)
      flight_max_seconds = 8.0,      -- one flight lasts at most this long
      flight_energy_per_second = 10, -- energy spent per second in the air
      talks_to_flowers = true,       -- flavour: near a crop a flower whispers (stub, six lines)
      shop_discount = 0.0,
      bake_bonus = 0.0,
      run_cost_mult = 1.0,
      oil_use_mult = 1.0,
      dark_light_mult = 1.0,
      float_bob_px = 0.0,
      glow_energy = 0.0,
      glow_energy_dark = 0.0,
      glow_scale = 0.0,
      glow_color = "",
    },
    -- Hobbit: bakes better cakes and gets a discount in the shops of Hyggebyen (copy: CHAR_HOBBIT_PERK).
    hobbit = {
      species = { "bertil", "bodil" },    -- the two hero chips (Bertil and Bodil Bøgeknop)
      skins = { "hobbit_pip", "hobbit_bodil", "hobbit_moss", "hobbit_bramble" },   -- the last two are retired
      default_skin = "hobbit_pip",
      dig_speed = 1.0,
      tool_cost_mult = 1.0,
      harvest_bonus_chance = 0.0,
      can_fly = false,
      flight_max_seconds = 0,
      flight_energy_per_second = 0,
      talks_to_flowers = false,
      shop_discount = 0.1,           -- 10% off in every shop; the ONE owner of the discount is Perks.total("discount")
      bake_bonus = 0.25,             -- +25% chance of one more output in the crafting category bake (P12)
      run_cost_mult = 1.0,
      oil_use_mult = 1.0,
      dark_light_mult = 1.0,
      float_bob_px = 0.0,
      glow_energy = 0.0,
      glow_energy_dark = 0.0,
      glow_scale = 0.0,
      glow_color = "",
    },
    -- Ghost (Spoegelse): hovers instead of walking, runs longer and sees in the dark (copy: CHAR_GHOST_PERK).
    ghost = {
      species = { "bu", "hviske" },                    -- the two hero chips
      skins = { "ghost_bu", "ghost_hviske" },
      default_skin = "ghost_bu",
      dig_speed = 1.0,
      tool_cost_mult = 1.0,
      harvest_bonus_chance = 0.0,
      can_fly = false,
      flight_max_seconds = 0,
      flight_energy_per_second = 0,
      talks_to_flowers = false,
      shop_discount = 0.0,
      bake_bonus = 0.0,
      run_cost_mult = 0.6,           -- running costs 40% less energy: 15/s -> 9/s (first sprint 6.7 s -> 11.1 s)
      oil_use_mult = 0.75,           -- one lantern fill lasts 200 s instead of 150 s
      dark_light_mult = 1.25,        -- the lantern light reaches 25% further: 630 px -> 787 px at full oil
      float_bob_px = 2.5,            -- floats +-2.5 px at 0.55 Hz on top of the baked hover
      glow_energy = 0.35,            -- soft pale-blue glow of the ghost itself, rides the night factor
      glow_energy_dark = 0.08,
      glow_scale = 0.9,
      glow_color = "bfe0ff",
    },
  },

  combat = {
    max_half_hearts = 10,            -- 5 hearts with halves
    swing_time = 0.28,               -- attack swing duration, s (hit window below)
    swing_active_start = 0.22,       -- the arc can hit from 22% ...
    swing_active_end = 0.72,         -- ... to 72% of the swing
    swing_radius = 197,              -- GROUND px
    swing_half_angle_deg = 62,
    swing_cooldown = 0.12,
    dodge_time = 0.30,
    dodge_distance = 317,            -- GROUND px
    dodge_iframes = 0.42,
    dodge_cooldown = 0.9,
    light_cooldown = 7.0,            -- fe-lys burst (key Q)
    light_radius = 550,              -- GROUND px
    light_stun = 1.6,
    drink_heal_half_hearts = 4,      -- health tonic (key R)
    hurt_iframes = 0.9,
    knockback = 433,                 -- GROUND px/s impulse on a hit enemy / hurt player
    oil_seconds = 150,               -- lantern oil per visit of the forest; a lantern_oil item adds 60 s
    oil_min_light = 0.35,            -- lantern light never shrinks below 35%
    oil_whisper_ratio = 0.2,         -- the forest whispers when the oil is at 20%; adventure.oil_empty_hurt_interval hurts at 0
  },
}
