-- quests/night_flower.lua
-- A rare night flower blooms only in the dark forest after midnight.

kind = "quest"
id = "night_flower"

objectives = {
  { id = "collect_night_bloom", target = 1, description = "Find natteblomsten" },
  { id = "return_before_dawn", target = 1, description = "Vend tilbage før daggry" },
}

rewards = {
  gold = 350,
  items = {
    moonflower_seeds = 5,
    fairy_dust = 1,
  },
}

meta = {
  giver = "baker_maja",
  category = "adventure",
  repeatable = true,
  cooldown_days = 5,
  requires_zone = "dark_forest",
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_NIGHT_FLOWER_OFFER",
  }
end

function on_accept(context)
  api.set_flag("night_flower_active", true)
  api.notification("Natteblomsten", "Den blomstrer kun i mørket...")
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("night_flower_active", false)
    api.set_flag("night_flower_found", true)
  end
end

function is_available(context)
  return not api.has_flag("night_flower_active")
end
