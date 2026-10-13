-- config/game_balance.lua
-- Central tuning knobs. Designers edit this without touching GDScript.

kind = "config"

config = {
  player = {
    walk_speed = 5.5,
    run_speed = 8.0,
    swim_speed = 3.0,
    max_health = 100,
    max_stamina = 100,
    stamina_regen_per_second = 2.0,
    interaction_range = 2.5,
  },

  farm = {
    plots_per_upgrade = 4,
    max_plots = 24,
    watering_duration_days = 1,
    fertilizer_boost = 0.25,
    scarecrow_range = 6.0,
  },

  crops = {
    turnip = { stages = 4, days_per_stage = 1, seasons = { "foraar", "sommer" }, sell_price = 45 },
    carrot = { stages = 5, days_per_stage = 1, seasons = { "foraar", "efteraar" }, sell_price = 65 },
    moonflower = { stages = 6, days_per_stage = 2, seasons = { "sommer", "efteraar" }, sell_price = 180 },
    pumpkin = { stages = 6, days_per_stage = 2, seasons = { "efteraar" }, sell_price = 120 },
  },

  economy = {
    starting_gold = 500,
    sell_price_ratio = 0.5,
    shop_refresh_hour = 8,
    tax_per_day = 0,
  },

  adventure = {
    dark_forest_unlock_day = 3,
    ore_respawn_days = 3,
    rare_gem_chance = 0.08,
    enemy_damage_base = 8,
    loot_table_size = 3,
  },

  time = {
    minutes_per_real_second = 2.0,
    day_start_hour = 6,
    day_end_hour = 24,
    auto_save_minutes = 30,
  },

  ui = {
    notification_duration_seconds = 4.0,
    dialogue_chars_per_second = 40.0,
  },
}
