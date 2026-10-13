-- quests/intro_lottery.lua
-- Intro quest: the fairy king's lottery granted you a treetop farm.
-- Demonstrates the Lua quest authoring format.

kind = "quest"
id = "intro_lottery"

objectives = {
  { id = "talk_to_mayor", target = 1, description = "Tal med feborgmesteren Lyra" },
  { id = "visit_farm", target = 1, description = "Besøg din nye trækronsgård" },
  { id = "plant_first_crop", target = 1, description = "Plant din første afgrøde" },
}

rewards = {
  gold = 250,
  items = {
    turnip_seeds = 10,
    watering_can_copper = 1,
  },
}

meta = {
  giver = "mayor_lyra",
  category = "intro",
  repeatable = false,
}

function on_offer(context)
  api.log("Intro-quest tilbydes: " .. id)
  api.notification("En ny quest!", "Feernes Konge har udvalgt dig...")
  return {
    available = true,
  }
end

function on_accept(context)
  api.set_flag("intro_started", true)
  api.log("Spilleren accepterede intro-questen")
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_accepted" then
    api.set_flag("intro_started", true)
  end
  if event == "quest_completed" then
    api.set_flag("intro_done", true)
    api.unlock_zone("city")
    api.notification("Velkommen til PongPong!", "Din gård venter i trækronerne.")
  end
end

function on_day_started(context)
  -- nothing daily yet
end

function is_available(context)
  return not api.has_flag("intro_done")
end
