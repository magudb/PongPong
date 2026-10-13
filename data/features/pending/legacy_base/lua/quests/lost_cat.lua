-- quests/lost_cat.lua
-- Find the fairy child's lost cat in the dark forest edge.

kind = "quest"
id = "lost_cat"

objectives = {
  { id = "search_forest", target = 1, description = "Søg i skovbrynet" },
  { id = "find_cat", target = 1, description = "Find den forsvundne kat" },
  { id = "return_cat", target = 1, description = "Bring katten hjem til Lily" },
}

rewards = {
  gold = 150,
  items = {
    friendship_token = 1,
    lucky_clover = 1,
  },
}

meta = {
  giver = "fairy_lily",
  category = "help",
  repeatable = true,
  cooldown_days = 5,
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_LOST_CAT_OFFER",
  }
end

function on_accept(context)
  api.set_flag("lost_cat_active", true)
  api.set_flag("cat_location_hidden", true)
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("lost_cat_active", false)
    api.set_flag("cat_location_hidden", false)
  end
end

function is_available(context)
  return not api.has_flag("lost_cat_active")
end
