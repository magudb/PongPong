-- quests/moonstone_crown.lua
-- Fairy King quest (PLAN 3.12).  Legendary reward: the Moon Crown.  Gate of home tier 9.

kind = "quest"
id = "moonstone_crown"

objectives = {
  {
    id = "collect_moonstone",
    target = 1,
    on = "item_gained",
    item = "moonstone",
    have = true,
    description_key = "OBJ_MOONSTONE_CROWN_COLLECT_MOONSTONE",
  },
  {
    id = "return_to_king",
    target = 1,
    on = "dialogue_started",
    npc = "fairy_king",
    after_others = true,
    description_key = "OBJ_MOONSTONE_CROWN_RETURN_TO_KING",
  },
}

rewards = {
  gold = 800,
  items = { circlet_moon_crown = 1, fairy_dust = 2 },
  friendship = { fairy_king = 2 },
}

meta = {
  giver = "fairy_king",
  location = "ZONE_CITY",
  tag = "SKOV",
  category = "adventure",
  repeatable = false,
  cooldown_days = 0,
  requires_zone = "dark_forest",
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_MOONSTONE_CROWN_OFFER",
  }
end

function on_accept(context)
  api.set_flag("moonstone_crown_active", true)
  api.notification("QUEST_MOONSTONE_CROWN_ACCEPT_TITLE", "QUEST_MOONSTONE_CROWN_ACCEPT_TEXT")
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("moonstone_crown_active", false)
    api.set_flag("moonstone_crown_done", true)
    api.notification("QUEST_MOONSTONE_CROWN_DONE_TITLE", "QUEST_MOONSTONE_CROWN_DONE_TEXT")
  end
end

function is_available(context)
  return not api.has_flag("moonstone_crown_done")
end
