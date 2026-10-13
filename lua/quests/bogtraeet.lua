-- quests/bogtraeet.lua
-- The math chain: after the three math quests Zephyr rewards the unique Book Tree.
-- Offered by Zephyr (dialogue fairy_wizard, quest_accept) once the three math flags are set; the only objective is to talk to him again (the chain itself is the is_available gate).

kind = "quest"
id = "bogtraeet"

objectives = {
  {
    id = "return_to_zephyr",
    target = 1,
    on = "dialogue_started",
    npc = "fairy_wizard",
    after_others = true,
    description_key = "OBJ_BOGTRAEET_RETURN_TO_ZEPHYR",
  },
}

rewards = {
  gold = 400,
  items = { bookshelf_book_tree = 1, fairy_dust = 2 },
  friendship = { fairy_wizard = 2 },
}

meta = {
  giver = "fairy_wizard",
  location = "ZONE_CITY",
  tag = "LÆR",
  category = "learning",
  repeatable = false,
  cooldown_days = 0,
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_BOGTRAEET_OFFER",
  }
end

function on_accept(context)
  api.set_flag("bogtraeet_active", true)
  api.notification("QUEST_BOGTRAEET_ACCEPT_TITLE", "QUEST_BOGTRAEET_ACCEPT_TEXT")
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("bogtraeet_active", false)
    api.set_flag("bogtraeet_done", true)
  end
end

function is_available(context)
  return api.has_flag("math_bakery_done") and api.has_flag("math_harvest_done") and api.has_flag("math_quiz_done")
end
