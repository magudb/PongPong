-- quests/first_animal.lua
-- Animal dealer Rosa helps you get your first farm animal: build a coop, adopt an animal, feed it three times.
-- The vocabulary is documented in quests/lost_cat.lua.

kind = "quest"
id = "first_animal"

objectives = {
  {
    id = "build_coop",
    target = 1,
    on = "building_built",
    type = "coop",
    description_key = "OBJ_FIRST_ANIMAL_BUILD_COOP",
  },
  {
    id = "adopt_animal",
    target = 1,
    on = "animal_adopted",
    description_key = "OBJ_FIRST_ANIMAL_ADOPT_ANIMAL",
  },
  {
    id = "feed_animal",
    target = 3,
    on = "animal_fed",
    description_key = "OBJ_FIRST_ANIMAL_FEED_ANIMAL",
  },
}

rewards = {
  gold = 200,
  items = {
    chicken_feed = 10,
    animal_treats = 5,
    brush = 1,
  },
}

meta = {
  giver = "farmer_rosa",
  location = "ZONE_FARM",
  tag = "BYG",
  category = "farm",
  repeatable = false,
  cooldown_days = 0,
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_FIRST_ANIMAL_OFFER",
  }
end

function on_accept(context)
  api.set_flag("first_animal_active", true)
  api.notification("LUANOTIF_FIRST_ANIMAL_ACCEPT_TITLE", "LUANOTIF_FIRST_ANIMAL_ACCEPT_TEXT")
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("first_animal_active", false)
    api.set_flag("has_first_animal", true)
  end
end

function is_available(context)
  return not api.has_flag("has_first_animal")
end
