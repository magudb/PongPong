-- DR7: explicit event bindings; progress and cooldowns belong to QuestManager.
kind = "quest"
id = "skovlift_intro"
objectives = {
  {
    id = "go_down",
    target = 1,
    description_key = "OBJ_SKOVLIFT_INTRO_GO_DOWN",
    on = "game_event",
    event = "dungeon_floor_entered",
  },
  {
    id = "light_rune",
    target = 1,
    description_key = "OBJ_SKOVLIFT_INTRO_LIGHT_RUNE",
    on = "game_event",
    event = "dungeon_runestone_activated",
  },
  {
    id = "bring_home",
    target = 1,
    description_key = "OBJ_SKOVLIFT_INTRO_BRING_HOME",
    on = "game_event",
    event = "dungeon_run_ended",
  },
  {
    id = "report",
    target = 1,
    on = "dialogue_started",
    npc = "guard_oak",
    after_others = true,
    description_key = "OBJ_SKOVLIFT_INTRO_REPORT",
  },
}
rewards = {
  gold = 100,
  items = {
    lantern_oil = 2,
    health_tonic = 1,
  },
  friendship = {
    guard_oak = 1,
  },
}
meta = {
  giver = "guard_oak",
  location = "ZONE_TRAETOPPEN",
  tag = "SKOV",
  category = "adventure",
  repeatable = false,
  cooldown_days = 0,
}

function on_offer(context)
  return { available = true, text_key = "QUEST_SKOVLIFT_INTRO_OFFER" }
end

function on_accept(context)
  return { ok = true }
end

function is_available(context)
  return true
end
