-- quests/pips_runde.lua
-- Pip's first quest (package V1-cast-data, Style Guide v2): the postman shows the newcomer round the treetops.  Say hello to Hoppe, Brumme and
-- Sofus, then go back to Pip.  It is the first letter in the farm mailbox and the city's little tutorial.
-- Text keys (localization/cast.csv): QUEST_PIPS_RUNDE_{TITLE,DESC,OFFER,CHOICE,REMIND,ACCEPT_*,DONE_*}, OBJ_PIPS_RUNDE_*.

kind = "quest"
id = "pips_runde"

objectives = {
  {
    id = "greet_hoppe",
    target = 1,
    on = "dialogue_started",
    npc = "gardener_hoppe",
    description_key = "OBJ_PIPS_RUNDE_GREET_HOPPE",
  },
  {
    id = "greet_brumme",
    target = 1,
    on = "dialogue_started",
    npc = "carpenter_brumme",
    description_key = "OBJ_PIPS_RUNDE_GREET_BRUMME",
  },
  {
    id = "greet_sofus",
    target = 1,
    on = "dialogue_started",
    npc = "bathkeeper_sofus",
    description_key = "OBJ_PIPS_RUNDE_GREET_SOFUS",
  },
  {
    id = "return_to_pip",
    target = 1,
    on = "dialogue_started",
    npc = "postman_pip",
    after_others = true,
    description_key = "OBJ_PIPS_RUNDE_RETURN_TO_PIP",
  },
}

rewards = {
  gold = 120,
  items = { friendship_token = 1 },
  friendship = { postman_pip = 1 },
}

meta = {
  giver = "postman_pip",
  location = "ZONE_TRAETOPPEN",
  tag = "FIND",
  category = "help",
  repeatable = false,
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_PIPS_RUNDE_OFFER",
  }
end

function on_accept(context)
  api.set_flag("pips_runde_active", true)
  api.notification("QUEST_PIPS_RUNDE_ACCEPT_TITLE", "QUEST_PIPS_RUNDE_ACCEPT_TEXT")
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("pips_runde_active", false)
    api.set_flag("pips_runde_done", true)
    api.notification("QUEST_PIPS_RUNDE_DONE_TITLE", "QUEST_PIPS_RUNDE_DONE_TEXT")
  end
end

function is_available(context)
  return not api.has_flag("pips_runde_done")
end
