-- quests/intro_lottery.lua
-- Intro quest: the Fairy King's lottery granted you a treetop farm.  IntroSequence (P14) accepts it for you at the start of a new game.
-- Plant the first crop, cross the farm bridge into Traetoppen (the farm bridge lands in the city; Hyggebyen is one bridge further and keeps
-- the zone id "city"), and say hello to the mayor in Hyggebyen.  The binding vocabulary is documented in quests/lost_cat.lua.
-- The five functions below are pinned by tests/sections/data.gd (the comment-only on_day_started is a parser regression of P10).

kind = "quest"
id = "intro_lottery"

objectives = {
  {
    id = "plant_first_crop",
    target = 1,
    on = "crop_planted",
    description_key = "OBJ_INTRO_LOTTERY_PLANT_FIRST_CROP",
  },
  {
    id = "cross_bridge",
    target = 1,
    on = "zone_entered",
    zone = "traetoppen",
    description_key = "OBJ_INTRO_LOTTERY_CROSS_BRIDGE",
  },
  {
    id = "talk_to_mayor",
    target = 1,
    on = "dialogue_started",
    npc = "mayor_lyra",
    description_key = "OBJ_INTRO_LOTTERY_TALK_TO_MAYOR",
  },
}

rewards = {
  gold = 250,
  items = {
    turnip_seeds = 10,
  },
}

meta = {
  giver = "mayor_lyra",
  location = "ZONE_FARM",
  tag = "FIND",
  category = "intro",
  repeatable = false,
  cooldown_days = 0,
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_INTRO_LOTTERY_OFFER",
  }
end

function on_accept(context)
  api.set_flag("intro_started", true)
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_accepted" then
    api.set_flag("intro_started", true)
  end
  if event == "quest_completed" then
    api.set_flag("intro_done", true)
    api.notification("LUANOTIF_INTRO_LOTTERY_DONE_TITLE", "LUANOTIF_INTRO_LOTTERY_DONE_TEXT")
  end
end

function on_day_started(context)
  -- nothing daily yet
end

function is_available(context)
  -- QuestManager owns one-shot completion. In existing v3 saves intro_done
  -- also meant "tutorial skipped/finished", not necessarily lottery progress.
  return true
end
