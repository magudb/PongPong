-- quests/lost_cat.lua
-- The guide quest (style guide screen 08): Pippin Boegeknop's grandfather Mis has wandered off again.  Ask the neighbours in Hyggebyen, follow the
-- paw prints by the bridge (a quest_spot of the farm map), find Morfar Mis in the Dark Wood, tell Pippin.
--
-- HOW AN OBJECTIVE IS COMPLETED (QuestManager, PLAN 3.12; the other quest files only point here):
--   on = "item_gained" item=<id>          [have = true: progress = how many you own, stays done once reached]
--   on = "crop_planted" / "crop_harvested" crop=<id>?       on = "crop_watered"
--   on = "zone_entered" zone=<zone id>    (fires on every area change; harmless for target 1)
--   on = "area_changed" area=<MAP id>     (a map id such as moerkeskoven_f4: several maps share one zone id)
--   on = "dialogue_started" npc=<id>  or  any_of = { <npc ids> }  (each listed npc counts once, target <= how many are listed)
--   on = "animal_adopted" / "animal_fed" / "animal_product_collected" product=<id> / "building_built" type=<id>
--   on = "enemy_defeated" kind=<id>       on = "recipe_crafted" recipe=<id>      on = "quest_completed" category=<list>
--   on = "game_event" event=<name> [rarity=<list>] [min_level=<n>] [match = { npc = "..", item = "..", id = ".." }]
--        min_level compares payload.level generically: the dungeon sends level = the floor number, furniture the hygge level index
--   on = "gift_given" npc item / "festival_attended" / "heart_event_finished" npc   (sugar over game_event of that name; a payload id: match = { id = ".." })
--   on = "state" state=placed_by_rarity | hygge_level_at_least | home_tier_at_least | friend_hearts_at_least  (a QUERY: re-evaluated, stays done)
--   on = "manual"                         (a quest_spot marker, a dialogue action or a Lua hook finishes it)
-- Flags: after_others = true (a turn-in: counts only once everything that is not a turn-in is done), needs = { item = n } with consume = true
-- (a delivery: the goods leave the backpack together with the progress), amount = n (progress per event).
-- Text: description_key = OBJ_<QUEST>_<OBJECTIVE> of localization/quests.csv; never a text literal in this file.

kind = "quest"
id = "lost_cat"

objectives = {
  {
    id = "ask_neighbours",
    target = 3,
    on = "dialogue_started",
    any_of = { "baker_maja", "merchant_pip", "mayor_lyra", "farmer_rosa" },
    description_key = "OBJ_LOST_CAT_ASK_NEIGHBOURS",
  },
  {
    id = "follow_pawprints",
    target = 1,
    on = "manual",
    description_key = "OBJ_LOST_CAT_FOLLOW_PAWPRINTS",
  },
  {
    id = "find_cat",
    target = 1,
    on = "dialogue_started",
    npc = "cat_morfar_mis",
    description_key = "OBJ_LOST_CAT_FIND_CAT",
  },
  {
    id = "return_cat",
    target = 1,
    on = "dialogue_started",
    npc = "pippin_boegeknop",
    after_others = true,
    description_key = "OBJ_LOST_CAT_RETURN_CAT",
  },
}

rewards = {
  gold = 150,
  items = { catnip_seeds = 3, hat_cat_ears = 1 },
  friendship = { pippin_boegeknop = 2 },
}

meta = {
  giver = "pippin_boegeknop",
  location = "ZONE_CITY",
  tag = "FIND",
  category = "help",
  repeatable = false,
  cooldown_days = 0,
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_LOST_CAT_OFFER",
  }
end

function on_accept(context)
  api.set_flag("lost_cat_active", true)
  api.set_flag("cat_location_hidden", true)
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("lost_cat_active", false)
    api.set_flag("cat_location_hidden", false)
  end
end

function is_available(context)
  return not api.has_flag("lost_cat_active")
end
