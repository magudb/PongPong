-- DR7: explicit event bindings; progress and cooldowns belong to QuestManager.
kind = "quest"
id = "rune_vandring"
objectives = {
  {
    id = "rune_5",
    target = 1,
    description_key = "OBJ_RUNE_VANDRING_RUNE_5",
    on = "game_event",
    event = "dungeon_runestone_activated",
    min_level = 5,
  },
  {
    id = "rune_9",
    target = 1,
    description_key = "OBJ_RUNE_VANDRING_RUNE_9",
    on = "game_event",
    event = "dungeon_runestone_activated",
    min_level = 9,
  },
  {
    id = "report",
    target = 1,
    on = "dialogue_started",
    npc = "appraiser_fru_ugle",
    after_others = true,
    description_key = "OBJ_RUNE_VANDRING_REPORT",
  },
}
rewards = {
  items = {
    ugle_noegle = 1,
    gem_bag = 1,
  },
}
meta = {
  giver = "appraiser_fru_ugle",
  location = "ZONE_TRAETOPPEN",
  tag = "SKOV",
  category = "adventure",
  repeatable = false,
  cooldown_days = 0,
}

function on_offer(context)
  return { available = true, text_key = "QUEST_RUNE_VANDRING_OFFER" }
end

function on_accept(context)
  return { ok = true }
end

function is_available(context)
  return true
end
