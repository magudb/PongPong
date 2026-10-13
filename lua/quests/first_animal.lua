-- quests/first_animal.lua
-- Rosa helps you adopt your first farm animal.

kind = "quest"
id = "first_animal"

objectives = {
  { id = "build_coop", target = 1, description = "Byg et hønsehus" },
  { id = "adopt_animal", target = 1, description = "Adoptér dit første dyr" },
  { id = "feed_animal", target = 3, description = "Fodr dit dyr 3 gange" },
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
  category = "farm",
  repeatable = false,
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_FIRST_ANIMAL_OFFER",
  }
end

function on_accept(context)
  api.set_flag("first_animal_active", true)
  api.notification("Dit første dyr!", "Rosa hjælper dig med at komme i gang!")
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
