-- quests/math_harvest_puzzle.lua
-- Animal dealer Rosa needs exact amounts for her market stall: the objective TARGETS are the answers to small multiplication problems
-- (3 x 4 carrots, 7 x 3 stones, 4 x 2 rare mushrooms).  The vocabulary is documented in quests/lost_cat.lua.

kind = "quest"
id = "math_harvest_puzzle"

objectives = {
  {
    id = "math_harvest_carrot",
    target = 12,
    on = "crop_harvested",
    crop = "carrot",
    description_key = "OBJ_MATH_HARVEST_PUZZLE_MATH_HARVEST_CARROT",
  },
  {
    id = "math_collect_stone",
    target = 21,
    on = "item_gained",
    item = "stone",
    have = true,
    description_key = "OBJ_MATH_HARVEST_PUZZLE_MATH_COLLECT_STONE",
  },
  {
    id = "math_collect_mushroom",
    target = 8,
    on = "item_gained",
    item = "rare_mushroom",
    have = true,
    description_key = "OBJ_MATH_HARVEST_PUZZLE_MATH_COLLECT_MUSHROOM",
  },
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
  location = "ZONE_CITY",
  tag = "LÆR",
  category = "learning",
  repeatable = false,
  cooldown_days = 0,
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
