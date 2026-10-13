-- quests/math_harvest_puzzle.lua
-- Farmer Rosa needs exact amounts for her market stall. The objective
-- targets ARE the answers to small arithmetic problems.

kind = "quest"
id = "math_harvest_puzzle"

objectives = {
  { id = "harvest_carrot", target = 12, description = "Høst gulerødder: 3 × 4" },
  { id = "collect_stone", target = 21, description = "Saml sten: 7 × 3" },
  { id = "collect_rare_mushroom", target = 8, description = "Find sjældne svampe: 4 × 2" },
}

rewards = {
  gold = 100,
  items = {
    carrot_seeds = 4,
    lucky_clover = 1,
  },
}

meta = {
  giver = "farmer_rosa",
  category = "learning",
  repeatable = false,
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_MATH_HARVEST_PUZZLE_OFFER",
  }
end

function on_accept(context)
  api.set_flag("math_harvest_active", true)
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("math_harvest_done", true)
    api.set_flag("math_harvest_active", false)
  end
end

function is_available(context)
  return not api.has_flag("math_harvest_done")
end
