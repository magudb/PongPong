-- quests/math_wizard_quiz.lua
-- Zephyr the fairy wizard tests the player's multiplication tables.  Each riddle is a dialogue choice (action math_answer in
-- lua/dialogue/fairy_wizard.lua): a correct answer finishes the manual objective.  The vocabulary is documented in quests/lost_cat.lua.

kind = "quest"
id = "math_wizard_quiz"

objectives = {
  { id = "math_wiz_q1", target = 1, on = "manual", description_key = "OBJ_MATH_WIZARD_QUIZ_MATH_WIZ_Q1" },
  { id = "math_wiz_q2", target = 1, on = "manual", description_key = "OBJ_MATH_WIZARD_QUIZ_MATH_WIZ_Q2" },
  { id = "math_wiz_q3", target = 1, on = "manual", description_key = "OBJ_MATH_WIZARD_QUIZ_MATH_WIZ_Q3" },
}

rewards = {
  gold = 120,
  items = { magic_scroll = 1, fairy_dust = 5, hat_wizard_zephyr = 1 },
  friendship = { fairy_wizard = 1 },
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
    text_key = "QUEST_MATH_WIZARD_QUIZ_OFFER",
  }
end

function on_accept(context)
  api.set_flag("math_quiz_active", true)
  api.notification("LUANOTIF_MATH_WIZARD_QUIZ_ACCEPT_TITLE", "LUANOTIF_MATH_WIZARD_QUIZ_ACCEPT_TEXT")
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("math_quiz_done", true)
    api.set_flag("math_quiz_active", false)
  end
end

function is_available(context)
  return not api.has_flag("math_quiz_done")
end
