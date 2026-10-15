-- quests/forest_patrol.lua
-- Guard Oak wants someone to walk a round at the forest edge: step into the Dark Wood (zone dark_forest; zone_entered fires on every floor change,
-- which is harmless for a target of 1), bring back six moss as proof, report to Oak.  Repeatable after the cooldown.
-- The vocabulary is documented in quests/lost_cat.lua.

kind = "quest"
id = "forest_patrol"

objectives = {
  {
    id = "enter_forest_edge",
    target = 1,
    on = "zone_entered",
    zone = "dark_forest",
    description_key = "OBJ_FOREST_PATROL_ENTER_FOREST_EDGE",
  },
  {
    id = "collect_moss",
    target = 6,
    on = "item_gained",
    item = "moss",
    have = true,
    description_key = "OBJ_FOREST_PATROL_COLLECT_MOSS",
  },
  {
    id = "return_to_oak",
    target = 1,
    on = "dialogue_started",
    npc = "guard_oak",
    after_others = true,
    description_key = "OBJ_FOREST_PATROL_RETURN_TO_OAK",
  },
}

rewards = {
  gold = 220,
  items = {
    iron_ore = 3,
    friendship_token = 1,
  },
}

meta = {
  giver = "guard_oak",
  location = "ZONE_CITY",
  tag = "SKOV",
  category = "adventure",
  repeatable = true,
  cooldown_days = 3,
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_FOREST_PATROL_OFFER",
  }
end

function on_accept(context)
  api.set_flag("forest_patrol_active", true)
  api.notification("LUANOTIF_FOREST_PATROL_ACCEPT_TITLE", "LUANOTIF_FOREST_PATROL_ACCEPT_TEXT")
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("forest_patrol_active", false)
  end
end

function is_available(context)
  return not api.has_flag("forest_patrol_active")
end
