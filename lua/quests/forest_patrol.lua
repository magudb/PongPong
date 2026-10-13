-- quests/forest_patrol.lua
-- Guard Oak needs help patrolling the forest edge and clearing threats.

kind = "quest"
id = "forest_patrol"

objectives = {
  { id = "enter_forest_edge", target = 1, description = "Patruljér skovbrynet" },
  { id = "collect_moss", target = 6, description = "Saml 6 mos som bevis" },
  { id = "return_to_oak", target = 1, description = "Rapporter tilbage til Oak" },
}

rewards = {
  gold = 220,
  items = {
    iron_ore = 3,
    friendship_token = 1,
  },
}

meta = {
  giver = "guard_oak",
  category = "adventure",
  repeatable = true,
  cooldown_days = 3,
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_FOREST_PATROL_OFFER",
  }
end

function on_accept(context)
  api.set_flag("forest_patrol_active", true)
  api.notification("Skovpatrulje", "Vær på vagt i skovbrynet!")
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("forest_patrol_active", false)
  end
end

function is_available(context)
  return not api.has_flag("forest_patrol_active")
end
