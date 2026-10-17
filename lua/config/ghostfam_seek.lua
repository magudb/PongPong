-- config/ghostfam_seek.lua  (GF-seek, wave 6; the DATA of Blund's counted hide and seek: the slots equal the `hide` blocks of lua/routines/ghostfam/ghostfam_blund.lua, a validator of GF-data proves it)
-- Rules (user answer 4, 2026-10-14: "a counted game with rewards"): Blund hides TWICE every evening (slot A 18:00-20:30, slot B from about 21:00 to 23:30; the hours are game hours on the 6..26 axis), never on
-- Wednesday (Familieaften).  A `find` = the player talks to the hidden Blund (invisible, a faint shimmer shows where) while he is at the slot's post; at most ONE find per slot and day = 2 a day
-- (`daily_cap`).  No failure state: a missed slot costs nothing and the game restarts the next evening.  Every find pays `find_points` (SocialManager.add_points, source seek: 5 points = a twentieth of a
-- heart; 12 finds a week = 0.6 heart) and counts on the card; the ladder pays ONE item per rarity at the find count (a flag bitmask, claimed once per save).  The ladder items are EXISTING lamps, one per rarity
-- (lua/items/furniture.lua): the two top ones cannot be sold (sell_ratio 0 for unique and legendary), the rest sums to 370 gold once (scripts/economy_check6.py).
-- KEEPSAKES (final edit, reviewer B major 1): the unique (floor_lamp_glowshroom) and the legendary (floor_lamp_fairy) lamp are ONE-OF-A-KIND keepsakes (max_stack 1, protected; EconomyManager.add_item refuses a second
-- copy; the dungeon registry loot.dungeon.found never finds one twice) and each already has a fixed source of its own (a wanderer of the fe chests, the boss pool of the snurresvamp).  Before a step whose item is
-- one-of-a-kind (rarity unique / legendary) is paid the seek script tests EconomyManager.count_item(item) >= 1 (placed and worn pieces count) or LootService.found(item); an owner gets the step's `fallback` item (a
-- sellable rare lamp) and the step's `fallback_gift_key` line instead, the claimed bit is set once the item was ACCEPTED, and the 'bag full' toast is only for a bag that really has no room.  Items are delivered
-- through LootService.deliver when it exists (it writes the keepsake registry), else EconomyManager.add_item.
-- JSON-safe flags (GameManager.world_flags, saved in the game section; ints come back as floats: flag_int), the six names are listed in `flags` below: ghostfam_seek_total (int), ghostfam_seek_claimed (int bitmask,
-- bit 0 = step 1), ghostfam_seek_day (int total_day of the last find), ghostfam_seek_today (int bitmask of the slots found that day: 1 = A, 2 = B), ghostfam_seek_found_now (int 0 / 1 / 2, transient: written by the
-- seek script just before Blund's dialogue starts, read by his dialogue module, cleared by it) and ghostfam_seek_gift_now (int, transient: the ladder step that was paid by this find, 1..5, plus 10 when the
-- fallback was paid; written by the seek script together with found_now, cleared by Blund's module together with it).
kind = "config"

config = {
  ghostfam_seek = {
    npc = "ghostfam_blund",
    daily_cap = 2,
    find_points = 5,
    hint = { shimmer_px = 260, warm_px = 320, hot_px = 140, find_px = 72 },
    kin = { shimmer_mult = 1.5 },
    ladder = {
      { finds = 3, item = "table_lamp_clay", rarity = "normal", gift_key = "SEEK_GHOSTFAM_GIFT_1" },
      { finds = 10, item = "floor_lamp_honey", rarity = "uncommon", gift_key = "SEEK_GHOSTFAM_GIFT_2" },
      { finds = 24, item = "candelabra_brass", rarity = "rare", gift_key = "SEEK_GHOSTFAM_GIFT_3" },
      { finds = 48, item = "floor_lamp_glowshroom", rarity = "unique", gift_key = "SEEK_GHOSTFAM_GIFT_4", fallback = "table_lamp_brass", fallback_gift_key = "SEEK_GHOSTFAM_GIFT_4_OWNED" },
      { finds = 80, item = "floor_lamp_fairy", rarity = "legendary", gift_key = "SEEK_GHOSTFAM_GIFT_5", fallback = "candelabra_brass", fallback_gift_key = "SEEK_GHOSTFAM_GIFT_5_OWNED" },
    },
    flags = {
      ghostfam_seek_total = "int", ghostfam_seek_claimed = "int", ghostfam_seek_day = "int", ghostfam_seek_today = "int", ghostfam_seek_found_now = "int", ghostfam_seek_gift_now = "int",
    },
    slots = {
      { weekday = 0, a = { area = "traetoppen", post = "g_planter2" }, b = { area = "traetoppen", post = "c_lamp" } },
      { weekday = 1, a = { area = "traetoppen", post = "c_logs" }, b = { area = "traetoppen", post = "u_lamp" } },
      { weekday = 3, a = { area = "traetoppen", post = "a_beds2" }, b = { area = "traetoppen", post = "b_mailbox" } },
      { weekday = 4, a = { area = "traetoppen", post = "e_bench" }, b = { area = "hyggebyen", post = "market_row3" } },
      { weekday = 5, a = { area = "traetoppen", post = "g_bench" }, b = { area = "hyggebyen", post = "torv_playground" } },
      { weekday = 6, a = { area = "traetoppen", post = "u_terrace" }, b = { area = "hyggebyen", post = "forge_front" } },
    },
  },
}
