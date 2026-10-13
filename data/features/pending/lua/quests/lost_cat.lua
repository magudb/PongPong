-- quests/lost_cat.lua
-- Find the fairy child's lost cat in the dark forest edge.

-- FEATURES: rewards = the style guide's three chips (150 guldagern, Kattemynte-frø x 3, heart Pippin) + the rare cat-ear beanie (hat_cat_ears); non-repeatable (the beanie must be earned once), giver/location per PLAN 3.12.

kind = "quest"
id = "lost_cat"

objectives = {
  { id = "search_forest", target = 1, description = "Søg i skovbrynet" },
  { id = "find_cat", target = 1, description = "Find den forsvundne kat" },
  { id = "return_cat", target = 1, description = "Bring katten hjem til Pippin" },
}

rewards = {
  gold = 150,
  items = { catnip_seeds = 3, hat_cat_ears = 1 },
  friendship = { pippin_boegeknop = 2 },
}

meta = {
  giver = "pippin_boegeknop",
  location = "ZONE_CITY",
  tag = "FIND",
  category = "help",
  repeatable = false,
  cooldown_days = 0,
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
