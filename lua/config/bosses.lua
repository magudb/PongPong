kind = "config"
-- dazed (= recover) is the punish window after a dash or ring; tests/sections/combat_acceptance.gd holds the fight lengths.
-- Bosses 1 and 2 daze 2.4 / 2.0 s instead of the combat model's 1.8 / 1.7 s: since a hit no longer cuts the daze short and
-- only the drawn band hurts, walking back into reach ate most of a 1.8 s daze (four in ten ended without a hit) and the
-- first boss took 39 s instead of the model's 18.
config = {
  bosses = {
    snurresvamp = { name_key = "BOSS_SNURRESVAMPEN", visual = "snurresvamp", tint = "ffffff", glow = "d4e9b4", hits = 8, floor = 4, hp = 80, windup = 1.0, dazed = 2.4, recover = 2.4, damage = 1, speed = 140, detect = 900, armor = true, adds = 4, lunge_time = 0.5, patterns = { dash_speed = 540, dash_width = 90, puff_radius = 200, double_below = 0.33, double_gap = 0.6 } },
    snurresvamp_gloed = { name_key = "BOSS_GLOEDESVAMPEN", visual = "snurresvamp", tint = "e8b04a", glow = "e8b04a", hits = 11, floor = 8, hp = 176, windup = 1.0, dazed = 2.0, recover = 2.0, damage = 1, speed = 140, detect = 900, armor = true, adds = 6, lunge_time = 0.5, patterns = { dash_speed = 620, dash_width = 90, quake_radius = 260, cloud_radius = 150, cloud_seconds = 3, double_below = 0.5, double_gap = 0.6 } },
    snurresvamp_konge = { name_key = "BOSS_SVAMPEKONGEN", visual = "snurresvamp", tint = "7b6bb8", glow = "b9a3d4", hits = 12, floor = 12, hp = 288, windup = 0.9, dazed = 1.5, recover = 1.5, damage = 1, speed = 140, detect = 900, armor = true, adds = 8, lunge_time = 0.5, patterns = { dash_speed = 620, dash_width = 90, quake_radius = 260, cloud_radius = 150, cloud_seconds = 3, double_below = 0.5, double_gap = 0.6, rain_below = 0.66, rain_radius = 120, rain_volley = 3, rain_count = 3, rain_stagger = 0.35, rain_windup = 1.0 } },
  },
}
