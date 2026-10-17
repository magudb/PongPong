-- social/social.lua
-- The numbers of the social layer (hearts, chat, gifts, stages, festivals).  ONE config key: social.  Read by SocialManager and SocialData through
-- LuaRuntime.get_config("social.<path>"); EVERY value has the same default in code (SocialData.DEFAULTS, proven equal by social.config_defaults_equal_lua),
-- so a missing key or a missing file never breaks boot.
--   points_per_heart   a whole heart is 100 points; the flag friend_<npc> always holds WHOLE hearts (a derived mirror), the section `social` holds points
--   heart_cap          hearts stop here (10 hearts = 1000 points); nothing ever decays or goes negative
--   chat_points        the first FINISHED conversation of a calendar week (Monday..Sunday) is worth exactly one heart (the DF3 floor)
--   chat_min_lines     a conversation with fewer lines shown than this gives nothing (an empty module, an Esc before the first line)
--   toast_gap_s        real seconds between two friendship toasts: a second one waits its turn instead of stacking
--   gifts.*            class points, per-day / per-week limits, rarity and birthday multipliers, the repeat rule; read by S-gifts (the rows live in the section `social`)
--   purchase.*         shop friendliness: gold_per_point gold spent in a keeper's shop = 1 point, at most weekly_cap points per keeper and calendar week
--   festival.*         attend_points (S-events), max_attendees = the cap of ORDERED festival attendees (the host, the `first` list and the `guests` stand outside it)
--   stage_order / stage_hearts   friendship stage ids by hearts; the labels are the CSV rows REL_STAGE_<ID> (social_sys.csv)
--   rs_stages          OPTIONAL: stage ids the marriage-style row field `rs` (1, 2, 3) selects (S-marriage fills it: hjertven forlovet gift)
--   role_archetype     the taste / line archetype of an NPC without a citizens row, by the role of npcs.lua
-- Lua subset rules: literals only in tables, a list is never written as `{}` (an empty table arrives as an empty Dictionary).
kind = "config"

config = {
  social = {
    rs_stages = { "hjertven", "forlovet", "gift" },
    points_per_heart = 100,
    heart_cap = 10,
    chat_points = 100,
    chat_min_lines = 1,
    toast_gap_s = 1.5,
    gifts = {
      per_day = 1,
      per_week = 2,
      love = 40,
      like = 20,
      neutral = 8,
      dislike = 0,
      hate = 0,
      rarity_uncommon = 1.25,
      rarity_rare = 1.5,
      birthday_mult = 4.0,
      belated_mult = 2.0,
      belated_days = 1,
      repeat_days = 14,
      repeat_mult = 0.5,
      max_points = 160,
      known_cap = 40,
    },
    purchase = {
      gold_per_point = 100,
      weekly_cap = 10,
    },
    festival = {
      attend_points = 20,
      max_attendees = 15,
    },
    stage_order = { "fremmed", "bekendt", "nabo", "ven", "god_ven", "bedste_ven" },
    stage_hearts = { fremmed = 0, bekendt = 1, nabo = 2, ven = 4, god_ven = 6, bedste_ven = 8 },
    role_archetype = {
      mayor = "fairy", baker = "shopkeeper", shopkeeper = "shopkeeper", villager = "wanderer", king = "elder", child = "child",
      smith = "craftsman", guard = "watcher", animal_keeper = "gardener", wizard = "elder", elder = "elder", postman = "wanderer",
      builder = "craftsman", furnisher = "fairy", tailor = "fairy", gardener = "gardener", carpenter = "craftsman",
      bathkeeper = "elder", appraiser = "elder", mapseller = "watcher", beekeeper = "gardener",
      innkeeper = "shopkeeper", clerk = "watcher", musician = "wanderer", apprentice = "wanderer", lamplighter = "wanderer", baker_helper = "shopkeeper",
    },
  },
}
