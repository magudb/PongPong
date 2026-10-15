-- quests/crystal_cave.lua
-- Deep in the Dark Wood a cave full of crystals hides (the generated floors 10-12 carry the zone id crystal_cave).  Walk into the wood, collect five
-- crystal shards, explore the cave, report to Thorin.  Accepting unlocks the cave zone.  Offered once the player has been in the wood
-- (meta.requires_zone).  Repeatable after the cooldown.  The vocabulary is documented in quests/lost_cat.lua.

kind = "quest"
id = "crystal_cave"

objectives = {
  {
    id = "enter_dark_forest",
    target = 1,
    on = "zone_entered",
    zone = "dark_forest",
    description_key = "OBJ_CRYSTAL_CAVE_ENTER_DARK_FOREST",
  },
  {
    id = "collect_crystals",
    target = 5,
    on = "item_gained",
    item = "crystal_shard",
    have = true,
    description_key = "OBJ_CRYSTAL_CAVE_COLLECT_CRYSTALS",
  },
  {
    id = "explore_cave",
    target = 1,
    on = "zone_entered",
    zone = "crystal_cave",
    description_key = "OBJ_CRYSTAL_CAVE_EXPLORE_CAVE",
  },
  {
    id = "return_to_smith",
    target = 1,
    on = "dialogue_started",
    npc = "smith_thorin",
    after_others = true,
    description_key = "OBJ_CRYSTAL_CAVE_RETURN_TO_SMITH",
  },
}

rewards = {
  gold = 600,
  items = {
    amethyst = 3,
    emerald = 1,
    fairy_dust = 2,
  },
}

meta = {
  giver = "smith_thorin",
  location = "ZONE_CRYSTAL_CAVE",
  tag = "SKOV",
  category = "adventure",
  repeatable = true,
  cooldown_days = 7,
  requires_zone = "dark_forest",
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_CRYSTAL_CAVE_OFFER",
  }
end

function on_accept(context)
  api.set_flag("crystal_cave_active", true)
  api.unlock_zone("crystal_cave")
  api.notification("LUANOTIF_CRYSTAL_CAVE_ACCEPT_TITLE", "LUANOTIF_CRYSTAL_CAVE_ACCEPT_TEXT")
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("crystal_cave_active", false)
    api.set_flag("crystal_cave_discovered", true)
  end
end

function is_available(context)
  return not api.has_flag("crystal_cave_active")
end
