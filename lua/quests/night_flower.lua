-- quests/night_flower.lua
-- A rare night bloom opens only in the dark of the wood (the resource node `night_bloom` is there at night, on floor 2 of the generated forest;
-- DUNGEON_V2_ADDENDUM 2.7).  Find it, show it to Guard Oak.  Offered once the player has been in the wood (meta.requires_zone).  Repeatable after
-- the cooldown.  The vocabulary is documented in quests/lost_cat.lua.

kind = "quest"
id = "night_flower"

objectives = {
  {
    id = "collect_night_bloom",
    target = 1,
    on = "item_gained",
    item = "night_bloom",
    have = true,
    description_key = "OBJ_NIGHT_FLOWER_COLLECT_NIGHT_BLOOM",
  },
  {
    id = "return_to_oak",
    target = 1,
    on = "dialogue_started",
    npc = "guard_oak",
    after_others = true,
    description_key = "OBJ_NIGHT_FLOWER_RETURN_TO_OAK",
  },
}

rewards = {
  gold = 350,
  items = {
    moonflower_seeds = 5,
    fairy_dust = 1,
  },
}

meta = {
  giver = "guard_oak",
  location = "ZONE_DARK_FOREST",
  tag = "SKOV",
  category = "adventure",
  repeatable = true,
  cooldown_days = 5,
  requires_zone = "dark_forest",
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_NIGHT_FLOWER_OFFER",
  }
end

function on_accept(context)
  api.set_flag("night_flower_active", true)
  api.notification("LUANOTIF_NIGHT_FLOWER_ACCEPT_TITLE", "LUANOTIF_NIGHT_FLOWER_ACCEPT_TEXT")
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("night_flower_active", false)
    api.set_flag("night_flower_found", true)
  end
end

function is_available(context)
  return not api.has_flag("night_flower_active")
end
