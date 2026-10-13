-- quests/dark_forest_mining.lua
-- Venture into the dark forest to mine rare gems and metals.

kind = "quest"
id = "dark_forest_mining"

objectives = {
  { id = "enter_dark_forest", target = 1, description = "Træd ind i den mørke skov" },
  { id = "collect_iron", target = 6, description = "Bryd 6 jernmalm" },
  { id = "collect_amethyst", target = 2, description = "Find 2 ametyster" },
  { id = "return_to_smith", target = 1, description = "Vend tilbage til smeden Thorin" },
}

rewards = {
  gold = 500,
  items = {
    iron_sword = 1,
    gem_bag = 1,
  },
}

meta = {
  giver = "smith_thorin",
  category = "adventure",
  repeatable = true,
  cooldown_days = 7,
  requires_zone = "dark_forest",
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_DARK_FOREST_MINING_OFFER",
  }
end

function on_accept(context)
  api.unlock_zone("dark_forest")
  api.notification("Mørk skov", "Vær forsigtig! Tag en lygte med.")
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("mining_unlocked", true)
    api.add_gold(100) -- bonus for bravery
  end
end

function is_available(context)
  return true
end
