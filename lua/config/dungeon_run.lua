kind = "config"
config = {
  dungeon_run = {
    v = 1,
    hearts_per_boss = 2,                                   -- 0 removes Skovens hjerte (USER QUESTION 2)
    boss_kinds = { "snurresvamp", "snurresvamp_gloed", "snurresvamp_konge" },
    expected_weapon = { 5, 6, 8, 10, 12, 13, 15, 16, 18, 20, 22, 24 },
    deep_step = 2,                                         -- only used when floors above 12 exist
    class_hits_x10 = { light = 6, standard = 16, heavy = 24 },
    damage = { light = { 1, 1, 1, 2 }, standard = { 1, 2, 2, 2 }, heavy = { 1, 2, 2, 2 }, boss = { 1, 1, 1, 1 } },
    oil = { auto_refuel_at = 15, hurt_floor_half_hearts = 2, whisper_ratio_x100 = 20, min_light_x100 = 35,
            lantern_oil_item = "lantern_oil", elixir_item = "lysdraabe" },
    safe_radius = 520,
    feel = { buffer = 0.15, dodge_cancel_from = 0.4, hit_stop_frames = 3, shake_hit = 2, shake_hurt = 4, knockback_enemy = 550 },
    weapon_families = {
      sword  = { name_key = "WEAPON_FAMILY_SWORD",  time = 0.28, radius = 197, half_angle = 62, knockback = 433, cooldown = 0.12, damage_x1000 = 1000 },
      club   = { name_key = "WEAPON_FAMILY_CLUB",   time = 0.42, radius = 177, half_angle = 95, knockback = 693, cooldown = 0.12, damage_x1000 = 1350 },
      spear  = { name_key = "WEAPON_FAMILY_SPEAR",  time = 0.31, radius = 286, half_angle = 22, knockback = 346, cooldown = 0.12, damage_x1000 = 1080 },
      dagger = { name_key = "WEAPON_FAMILY_DAGGER", time = 0.20, radius = 158, half_angle = 70, knockback = 260, cooldown = 0.06, damage_x1000 = 650 },
      staff  = { name_key = "WEAPON_FAMILY_STAFF",  time = 0.34, radius = 197, half_angle = 48, knockback = 433, cooldown = 0.16, damage_x1000 = 1125 },
    },
    weapon_effects = { "heart_on_kill", "oil_on_kill", "moon_wave", "stun_chance", "quake", "light_arc", "reveal_chests", "light_boost" },
    assist = {
      defaults = { assist_preset = "none", assist_dmg = 0, assist_telegraph = 0, assist_hearts = 0, assist_arc = 0, assist_dodge = 0, assist_oil = 0,
                   assist_last_spark = 0, assist_auto_swing = 0, assist_auto_refuel = 1, assist_reduce_flash = 0, assist_hints = 1 },
      light = { assist_dmg = 1, assist_telegraph = 1, assist_hearts = 1, assist_arc = 1, assist_dodge = 1, assist_oil = 1 },
      cozy = { assist_dmg = 2, assist_telegraph = 2, assist_hearts = 2, assist_arc = 2, assist_dodge = 2, assist_oil = 2, assist_last_spark = 1, assist_auto_swing = 1 },
      windup_x100 = { 100, 120, 140 }, hearts_half = { 0, 2, 4 }, arc_pct = { 0, 5, 10 }, dodge_bonus_ms = { 0, 50, 100 },
    },
    tutorial = { spacing = 20, ids = { "hub", "lantern", "abilities", "eyes", "rune", "chest", "berry", "hulen", "boss", "weapon_weak", "assist" },
                 weak_ratio_x100 = 75 },
    summary = { gap = 1.2 },
    reveal = { feed = 3.2, rare = 4.5, unique = 3.0, legendary = 3.2, awe_radius = 800, awe_stun = 3.0, dim = 0.45, skip_unique = 0.8, skip_legendary = 1.0 },
    boss = { wake_radius = 520, berries = { 66, 33 }, wave_hp = { 66, 33 }, ring_visible = 900 },
    audio = { duck_db = 6, music_fade = 1.0 },
  },
}
