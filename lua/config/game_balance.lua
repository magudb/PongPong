-- config/game_balance.lua
-- Central tuning knobs: numbers only, designers edit this without touching GDScript.
-- Read with LuaRuntime.get_config("<table>.<key>", default).  Top-level tables of this file: player, farm, crops,
-- economy, adventure, time, ui (race_perks.lua owns race_perks + combat, rarity.lua owns rarity_tiers + perk_caps,
-- npcs.lua owns npcs; two config files must not define the same top-level key, the load-time lint reports it).
--
-- UNITS (2D game, plan 3.13): distances and speeds are GROUND px and px/s.  The sprites are now unscaled, so every
-- number is the 3D-spike value x 1/0.6 (timings are unchanged).  Crossing the view takes about 11 s at walk speed.
-- Lua subset rules: literals only in tables (no arithmetic, no identifiers), `{}` is avoided for lists.

kind = "config"

config = {
  -- player: read by Player2D (P06) through GameData.player_cfg / get_config("player.<key>")
  player = {
    walk_speed = 285,              -- ground px/s
    run_speed = 450,               -- ground px/s while `run` is held and stamina lasts
    accel = 2500,                  -- ground px/s^2 towards the wanted velocity
    decel = 3300,                  -- ground px/s^2 when no direction is held
    hop_impulse = 620,             -- visual hop (action `jump` in iso areas): start velocity, px/s
    gravity = 1750,                -- visual hop gravity, px/s^2
    flight_altitude = 150,         -- Fe flight: hover height above the ground shadow, px
    flight_climb = 225,            -- Fe flight: climb / descend speed, px/s
    body_rx = 25,                  -- collision ellipse of a figure, ground px (x radius)
    body_ry = 14.8,                -- collision ellipse of a figure, ground px (y radius, flattened by the 36 degree view)
    interaction_range = 45,        -- E-query circle at the facing cell, ground px (D20)
    max_health = 100,              -- legacy 3D scale; the 2D player uses combat.max_half_hearts
    max_stamina = 100,             -- energy ("Energi"); Perks.total("energy") is added on top
    stamina_regen_per_second = 12, -- energy regained per second while not running or working
    run_cost_per_second = 15,      -- energy spent per second while running
    run_recover_ratio = 0.2,       -- an exhausted run (stamina hit 0) ends again at 20% stamina
  },

  -- farm: FarmGrid (P06) rules that are not per crop
  farm = {
    harvest_yield = 1,             -- crops per harvest (race harvest_bonus_chance and fertilizer add +1)
    fertilizer_bonus_yield = 1,    -- fertilizer: the next harvest of that plot gives +1, once
    auto_water_days = 3,           -- fairy_dust_water waters a plot automatically for this many days
  },

  -- crops: read by FarmGrid through get_config("crops").  READY when growth_days >= stages * days_per_stage; a plot
  -- gains one growth day per watered day (rain waters everything).  seasons = ids foraar sommer efteraar vinter.
  -- water_window = { from, to } (game hours on the stored axis, see `time` below): the crop only grows when it was watered inside the window; from > to wraps:
  -- hour >= from or hour < to, so { 20, 6 } (moon crops) = 20:00-06:00 = the raw hours 20..25 and 2..5 (00:xx and 01:xx count, a watering at 01:30 belongs to the day that
  -- rolls at 02:00).  The sprite stage (crop_<id>_0..3) follows the growth ratio, not `stages`.
  -- Seed items (crop_id) live in lua/items: carrot/turnip/pumpkin/moonflower/glow_berry exist, strawberry, sunflower
  -- and catnip seeds are added by P12 (economy.csv names) - the entries are here so the farm needs no code change.
  crops = {
    turnip = { stages = 4, days_per_stage = 1, seasons = { "foraar", "sommer" }, sell_price = 45 },
    carrot = { stages = 4, days_per_stage = 1, seasons = { "foraar", "sommer", "efteraar" }, sell_price = 65 },
    pumpkin = { stages = 5, days_per_stage = 2, seasons = { "efteraar" }, sell_price = 160 },
    moonflower = { stages = 6, days_per_stage = 2, seasons = { "sommer", "efteraar" }, sell_price = 180, water_window = { from = 20, to = 6 } },
    glow_berry = { stages = 5, days_per_stage = 2, seasons = { "sommer", "efteraar" }, sell_price = 150 },
    strawberry = { stages = 4, days_per_stage = 1, seasons = { "foraar" }, sell_price = 55 },
    sunflower = { stages = 7, days_per_stage = 1, seasons = { "sommer", "efteraar" }, sell_price = 70 },
    catnip = { stages = 5, days_per_stage = 1, seasons = { "foraar", "sommer" }, sell_price = 55 },
    frost_kale = { stages = 4, days_per_stage = 1, seasons = { "vinter" }, sell_price = 60 },
  },

  -- economy: EconomyManager / ShopSystem (P12), HomeManager (F2)
  economy = {
    starting_gold = 500,           -- guldagern at the start of a new game
    sell_price_ratio = 0.5,        -- default sell price = buy price x ratio (rarity.lua overrides it per rarity for furniture/clothing)
    tax_per_day = 0,               -- reserved, 0 = off
    home_cost_scale = 1.0,         -- multiplier on the GOLD price of every home upgrade (lua/data/home_tiers.lua); 1.0 = as designed
  },

  -- adventure: Morkeskoven (P19) and the warps
  adventure = {
    dark_forest_unlock_day = 1,    -- the forest is open from day 1; the warp keeps the req_day gate code for tuning
    ore_respawn_days = 3,          -- depleted resource nodes respawn after this many days
    rare_gem_chance = 0.08,        -- chance of a rare gem from a crystal/ore node
    enemy_damage_base = 8,         -- legacy 3D value; the 2D enemies carry damage in lua/config/enemies.lua
    loot_table_size = 3,           -- legacy loot roll count
    oil_empty_hurt_interval = 12,  -- seconds between half-heart losses while the lantern oil is empty (0 = off)
  },

  -- time: TimeManager / GameManager (P02).  06:00-02:00 (game hours 6..25, 20 hours) at 2 game minutes per real second = 10 real minutes per day.
  -- THE CLOCK CONTRACT (docs/design/CLOCK_26_ADDENDUM.md): every hour of every Lua table is a float of GAME HOURS on the axis 6..26 (6.5 = 06:30, 25.0 = 01:00,
  -- 25.5 = 01:30); 24.0 and 25.5 belong to the SAME game day as 23.0; the day rolls (calendar, weather, bin, restock, crop growth, autosave) at day_end_hour.
  time = {
    minutes_per_real_second = 2.0,
    day_start_hour = 6,
    day_end_hour = 26,             -- game hour 26 = 02:00 passes the player out; the hours 24 and 25 are the SAME game day (shown 00:xx and 01:xx); valid 7..29
    days_per_season = 28,
    seasons = { "foraar", "sommer", "efteraar", "vinter" },
    first_weekday = 0,             -- weekday of day 1 of every season: 0 = Monday ... 6 = Sunday
    night_start_hour = 20,         -- is_night(): hour >= night_start_hour or hour < night_end_hour (the raw hours 24 and 25 count as night)
    night_end_hour = 5,
    auto_save_minutes = 30,
    -- weather rolled once per day: weights per season (normalised by the roller); ids klart regn taage sne torden
    weather_chances = {
      foraar = { klart = 0.60, regn = 0.25, taage = 0.15 },
      sommer = { klart = 0.72, regn = 0.16, torden = 0.12 },
      efteraar = { klart = 0.45, regn = 0.35, taage = 0.20 },
      vinter = { klart = 0.30, sne = 0.45, taage = 0.25 },
    },
  },

  -- ui
  ui = {
    notification_duration_seconds = 4.0,
    dialogue_chars_per_second = 40.0,   -- typewriter speed of the dialogue box
  },
}
