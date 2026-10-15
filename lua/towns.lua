-- lua/towns.lua - constants of the town simulation (config key `towns`; package T-towns-core, TOWNS addendum 4.5 / 4.9)
-- Hours are floats of GAME HOURS on the axis 6..26 (docs/design/CLOCK_26_ADDENDUM.md): 25.5 = 01:30 of the same game day, the day ends with the 02:00 pass-out.
kind = "config"

config = {
  towns = {
    npc_speed = 0.65,                  -- fraction of player.walk_speed (285) a citizen walks on a scheduled leg: 185 px/s
    portal_seconds = 0.5,              -- time to pass a door or a bridge end
    max_live_visuals = 16,             -- HARD cap of distinct NPC looks live in one area on an ordinary day (integration plan 5.6; 8.93 MB VRAM each)
    max_live_visuals_festival = 20,    -- the cap on a festival day (GHOST_FAMILY AGF4): social.festival.max_attendees 15 + the host 1 + the four family members = 20; the crowd is never dropped
                                       -- memory row "festival day" (AGF19): one distinct look = 9.33 MB warm, so the city peak is 314.7 + 4 x 9.33 = 352.0 MB (worst row 381.7 MB) against the 400 MB process cap; only read on a festival day
    plan_visual_peak = 14,             -- what the ROUTINES may ask on an ordinary day (validator towns.visual_budget); the 2 left are for guests and scripted scenes
    live_min_dwell = 0.05,             -- game hours a citizen stays at a place at least
    rain_shelter = { acts = { "sit", "tend", "play", "fish" }, from = 8.0, to = 19.0 },
    closing_whisper_minutes = 30,      -- whisper in a shop this long before closing time (ShopHours)
    curfew = { enabled = true, whisper = 25.5, go_home = 25.75 },   -- 01:30 whisper, 01:45 the night watch walks the player home (CLOCK_26 Q1: 30 / 15 minutes before the 02:00 pass-out)
    carrot_max_speed = 1.6,            -- a follower may catch up at 1.6 x the leg speed
    hours_enabled = true,              -- the ONE switch of the opening-hours rule: Hours.shop_open answers null while it is false (sections that are not about hours turn it off, DT55)
  },
}
