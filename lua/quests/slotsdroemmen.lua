-- quests/slotsdroemmen.lua
-- Long final quest after home tier 10 (available only in the Castle).  Two legendary rewards.
-- on = "state" objectives are QUERIES (placed_by_rarity, hygge_level_at_least) evaluated when the quest is accepted and on furniture_changed / hygge_changed / home_upgraded:
-- keepsakes already standing in the castle count, and picking one up and putting it down again does not (progress stays done once reached).  hold_feast is an event (festival_held).
-- Offered by the Fairy King (dialogue fairy_king, quest_accept) while home_tier == 10.

kind = "quest"
id = "slotsdroemmen"

objectives = {
  {
    id = "furnish_treasures",
    target = 6,
    on = "state",
    state = "placed_by_rarity",
    rarity = "unique,legendary",
    description_key = "OBJ_SLOTSDROEMMEN_FURNISH_TREASURES",
  },
  {
    id = "reach_royal_hygge",
    target = 1,
    on = "state",
    state = "hygge_level_at_least",
    min_level = 5,
    description_key = "OBJ_SLOTSDROEMMEN_REACH_ROYAL_HYGGE",
  },
  {
    id = "hold_feast",
    target = 1,
    on = "game_event",
    event = "festival_held",
    description_key = "OBJ_SLOTSDROEMMEN_HOLD_FEAST",
  },
  {
    id = "return_to_king",
    target = 1,
    on = "dialogue_started",
    npc = "fairy_king",
    after_others = true,
    description_key = "OBJ_SLOTSDROEMMEN_RETURN_TO_KING",
  },
}

rewards = {
  gold = 6000,
  items = { necklace_heart_of_tree = 1, fireplace_moon = 1 },
  friendship = { fairy_king = 3 },
}

meta = {
  giver = "fairy_king",
  location = "ZONE_FARM",
  tag = "BYG",
  category = "farm",
  repeatable = false,
  cooldown_days = 0,
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_SLOTSDROEMMEN_OFFER",
  }
end

function on_accept(context)
  api.set_flag("slotsdroemmen_active", true)
  api.notification("QUEST_SLOTSDROEMMEN_ACCEPT_TITLE", "QUEST_SLOTSDROEMMEN_ACCEPT_TEXT")
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("slotsdroemmen_active", false)
    api.set_flag("slotsdroemmen_done", true)
    api.notification("QUEST_SLOTSDROEMMEN_DONE_TITLE", "QUEST_SLOTSDROEMMEN_DONE_TEXT")
  end
end

function is_available(context)
  local tier = context.home_tier or home_tier or 1
  return tier == 10
end
