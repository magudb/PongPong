-- quests/math_wizard_quiz.lua
-- Zephyr the fairy wizard tests the player's multiplication tables.
-- Each question is a dialogue choice; correct answers advance objectives.

-- FEATURES: rewards + the unique Zephyr's wizard hat (hat_wizard_zephyr).

kind = "quest"
id = "math_wizard_quiz"

objectives = {
  { id = "math_wiz_q1", target = 1, description = "Løs Zephyrs første gåde: 6 × 7" },
  { id = "math_wiz_q2", target = 1, description = "Løs Zephyrs anden gåde: 8 × 9" },
  { id = "math_wiz_q3", target = 1, description = "Løs Zephyrs tredje gåde: 7 × 4" },
}

rewards = {
  gold = 120,
  items = { magic_scroll = 1, fairy_dust = 5, hat_wizard_zephyr = 1 },
  friendship = { fairy_wizard = 1 },
}

meta = {
  giver = "fairy_wizard",
  category = "learning",
  repeatable = false,
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_MATH_WIZARD_QUIZ_OFFER",
  }
end

function on_accept(context)
  api.set_flag("math_quiz_active", true)
  api.notification("Regnemagi", "Tal til Zephyr og løs hans regnegåder!")
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
