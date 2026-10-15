-- quests/math_bakery_counts.lua
-- Baker-fairy Rosmarin has lost count of her baked goods: addition and subtraction problems the player solves through dialogue choices.
-- The three objectives are manual: the dialogue action math_answer (lua/dialogue/baker_maja.lua, objective_id) finishes them.
-- The vocabulary is documented in quests/lost_cat.lua.

kind = "quest"
id = "math_bakery_counts"

objectives = {
  { id = "math_maja_q1", target = 1, on = "manual", description_key = "OBJ_MATH_BAKERY_COUNTS_MATH_MAJA_Q1" },
  { id = "math_maja_q2", target = 1, on = "manual", description_key = "OBJ_MATH_BAKERY_COUNTS_MATH_MAJA_Q2" },
  { id = "math_maja_q3", target = 1, on = "manual", description_key = "OBJ_MATH_BAKERY_COUNTS_MATH_MAJA_Q3" },
}

rewards = {
  gold = 80,
  items = {
    cookie = 3,
  },
}

meta = {
  giver = "baker_maja",
  location = "ZONE_CITY",
  tag = "LÆR",
  category = "learning",
  repeatable = false,
  cooldown_days = 0,
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_MATH_BAKERY_COUNTS_OFFER",
  }
end

function on_accept(context)
  api.set_flag("math_bakery_active", true)
  api.notification("LUANOTIF_MATH_BAKERY_COUNTS_ACCEPT_TITLE", "LUANOTIF_MATH_BAKERY_COUNTS_ACCEPT_TEXT")
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("math_bakery_done", true)
    api.set_flag("math_bakery_active", false)
  end
end

function is_available(context)
  return not api.has_flag("math_bakery_done")
end
