-- quests/dark_forest_mining.lua
-- Smith Thorin is short of ore: step into the Dark Wood (zone dark_forest; zone_entered fires on every floor change, harmless for a target of 1),
-- bring back six iron ore and two amethysts, report to Thorin.  Offered once the player has been in the wood (meta.requires_zone, as in the
-- legacy file; accepting it also unlocks the zone).  Repeatable after the cooldown.  The vocabulary is documented in quests/lost_cat.lua.

kind = "quest"
id = "dark_forest_mining"

objectives = {
  {
    id = "enter_dark_forest",
    target = 1,
    on = "zone_entered",
    zone = "dark_forest",
    description_key = "OBJ_DARK_FOREST_MINING_ENTER_DARK_FOREST",
  },
  {
    id = "collect_iron",
    target = 6,
    on = "item_gained",
    item = "iron_ore",
    have = true,
    description_key = "OBJ_DARK_FOREST_MINING_COLLECT_IRON",
  },
  {
    id = "collect_amethyst",
    target = 2,
    on = "item_gained",
    item = "amethyst",
    have = true,
    description_key = "OBJ_DARK_FOREST_MINING_COLLECT_AMETHYST",
  },
  {
    id = "return_to_smith",
    target = 1,
    on = "dialogue_started",
    npc = "smith_thorin",
    after_others = true,
    description_key = "OBJ_DARK_FOREST_MINING_RETURN_TO_SMITH",
  },
}

rewards = {
  gold = 600,
  items = {
    iron_sword = 1,
    gem_bag = 1,
  },
}

meta = {
  giver = "smith_thorin",
  location = "ZONE_DARK_FOREST",
  tag = "SKOV",
  category = "adventure",
  repeatable = true,
  cooldown_days = 7,
  requires_zone = "dark_forest",
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_DARK_FOREST_MINING_OFFER",
  }
end

function on_accept(context)
  api.unlock_zone("dark_forest")
  api.notification("LUANOTIF_DARK_FOREST_MINING_ACCEPT_TITLE", "LUANOTIF_DARK_FOREST_MINING_ACCEPT_TEXT")
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("mining_unlocked", true)
  end
end

function is_available(context)
  return true
end
