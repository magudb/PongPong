-- quests/crystal_cave.lua
-- Deep in the dark forest lies a crystal cave with rare gems.

kind = "quest"
id = "crystal_cave"

objectives = {
  { id = "enter_dark_forest", target = 1, description = "Træd ind i den mørke skov" },
  { id = "collect_crystals", target = 5, description = "Bryd 5 krystaller" },
  { id = "explore_cave", target = 1, description = "Udforsk krystalgrotten" },
  { id = "return_to_smith", target = 1, description = "Vend tilbage til Thorin" },
}

rewards = {
  gold = 600,
  items = {
    amethyst = 3,
    emerald = 1,
    fairy_dust = 2,
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
    text_key = "QUEST_CRYSTAL_CAVE_OFFER",
  }
end

function on_accept(context)
  api.set_flag("crystal_cave_active", true)
  api.unlock_zone("crystal_cave")
  api.notification("Krystalgrotten", "En skjult grotte venter i dybet...")
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("crystal_cave_active", false)
    api.set_flag("crystal_cave_discovered", true)
  end
end

function is_available(context)
  return true
end
