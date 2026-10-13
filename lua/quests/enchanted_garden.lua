-- quests/enchanted_garden.lua
-- Unlock and tend a special enchanted garden plot.

kind = "quest"
id = "enchanted_garden"

objectives = {
  { id = "collect_rare_seeds", target = 3, description = "Find 3 sjældne frø" },
  { id = "water_garden", target = 3, description = "Vand haven 3 gange" },
  { id = "plant_enchanted", target = 2, description = "Plant 2 fortryllede afgrøder" },
}

rewards = {
  gold = 450,
  items = {
    moonflower_seeds = 5,
    fairy_dust = 2,
    friendship_token = 3,
  },
}

meta = {
  giver = "mayor_lyra",
  category = "farm",
  repeatable = true,
  cooldown_days = 10,
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_ENCHANTED_GARDEN_OFFER",
  }
end

function on_accept(context)
  api.set_flag("enchanted_garden_active", true)
  api.notification("Den Fortryllede Have", "En magisk have venter!")
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("enchanted_garden_active", false)
    api.set_flag("enchanted_garden_unlocked", true)
  end
end

function is_available(context)
  return not api.has_flag("enchanted_garden_unlocked")
end
