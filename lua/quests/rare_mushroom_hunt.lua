-- quests/rare_mushroom_hunt.lua
-- Lily's pet needs a glowing mushroom for medicine.

kind = "quest"
id = "rare_mushroom_hunt"

objectives = {
  { id = "collect_mushrooms", target = 4, description = "Saml 4 svampe" },
  { id = "find_glowing", target = 1, description = "Find den glødende svamp" },
  { id = "deliver_to_lily", target = 1, description = "Aflever til Lily" },
}

rewards = {
  gold = 180,
  items = {
    rare_mushroom = 2,
    lucky_clover = 1,
    friendship_token = 2,
  },
}

meta = {
  giver = "fairy_lily",
  category = "help",
  repeatable = true,
  cooldown_days = 4,
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_RARE_MUSHROOM_HUNT_OFFER",
  }
end

function on_accept(context)
  api.set_flag("mushroom_hunt_active", true)
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("mushroom_hunt_active", false)
    api.set_flag("glowing_mushroom_found", true)
  end
end

function is_available(context)
  return not api.has_flag("mushroom_hunt_active")
end
