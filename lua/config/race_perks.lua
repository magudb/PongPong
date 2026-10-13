-- config/race_perks.lua
-- Race perks and combat tuning as DATA (D14): game code only reads numbers/flags, designers change them here.
-- Top-level tables of this file: race_perks, combat.  Read with LuaRuntime.get_config("race_perks.<race>.<key>") /
-- get_config("combat.<key>") (GameData.perk / GameData.combat in P04).  Race ids: animal fairy hobbit
-- (GameManager.CharacterType 0 1 2).
--
-- UNITS (plan 3.13): distances and speeds are GROUND px; the sprites are unscaled now, so every distance and speed is the
-- 3D/spike value x 1/0.6 (swing_radius 118 -> 197, dodge_distance 190 -> 317, light_radius 330 -> 550, knockback 260 -> 433).
-- Timings (seconds) are unchanged.  Every race defines EVERY perk key (neutral value when the race has no such perk), so
-- code never has to guess a default.

kind = "config"

config = {
  race_perks = {
    -- Forest animal (Skovdyr): strong paws, digs faster and gets more from the harvest (copy: CHAR_ANIMAL_PERK).
    animal = {
      species = { "fox", "rabbit", "hedgehog", "squirrel" },    -- the four species chips (Ræv, Kanin, Pindsvin, Egern)
      skins = { "animal_fox", "animal_rabbit", "animal_hedgehog", "animal_squirrel" },   -- skin ids of lua/config/characters.lua
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
    },
    -- Fairy (Fe): can fly briefly over the fields and talks to flowers (copy: CHAR_FAIRY_PERK).
    fairy = {
      species = { "meadow", "stardust", "dusk" },
      skins = { "fairy_meadow", "fairy_stardust", "fairy_dusk" },
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
    },
    -- Hobbit: bakes better cakes and gets a discount in the shops of Hyggebyen (copy: CHAR_HOBBIT_PERK).
    hobbit = {
      species = { "pip", "moss", "bramble" },
      skins = { "hobbit_pip", "hobbit_moss", "hobbit_bramble" },
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
