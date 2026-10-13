-- quests/math_bakery_counts.lua
-- Baker Maja has lost track of her baked goods. Addition and subtraction
-- word problems for the player to solve via dialogue choices.

kind = "quest"
id = "math_bakery_counts"

objectives = {
  { id = "math_maja_q1", target = 1, description = "Hjælp Maja: 35 boller − 17 solgte" },
  { id = "math_maja_q2", target = 1, description = "Hjælp Maja: 28 småkager + 15 nye" },
  { id = "math_maja_q3", target = 1, description = "Hjælp Maja: 64 æbler − 29 spiste" },
}

rewards = {
  gold = 80,
  items = {
    cookie = 3,
  },
}

meta = {
  giver = "baker_maja",
  category = "learning",
  repeatable = false,
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_MATH_BAKERY_COUNTS_OFFER",
  }
end

function on_accept(context)
  api.set_flag("math_bakery_active", true)
  api.notification("Bageri-regning", "Tal til Maja og hjælp hende med regnskabet!")
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
