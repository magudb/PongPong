-- quests/animal_products.lua
-- Animal dealer Rosa needs fresh eggs and milk for her market stall.  The products the animals give end up in the backpack (have = true counts
-- them); the delivery takes five eggs and three bottles of milk out of it.  Repeatable after the cooldown.
-- The vocabulary is documented in quests/lost_cat.lua.

kind = "quest"
id = "animal_products"

objectives = {
  {
    id = "collect_egg",
    target = 5,
    on = "item_gained",
    item = "egg",
    have = true,
    description_key = "OBJ_ANIMAL_PRODUCTS_COLLECT_EGG",
  },
  {
    id = "collect_milk",
    target = 3,
    on = "item_gained",
    item = "milk",
    have = true,
    description_key = "OBJ_ANIMAL_PRODUCTS_COLLECT_MILK",
  },
  {
    id = "deliver_to_rosa",
    target = 1,
    on = "dialogue_started",
    npc = "farmer_rosa",
    after_others = true,
    needs = { egg = 5, milk = 3 },
    consume = true,
    description_key = "OBJ_ANIMAL_PRODUCTS_DELIVER_TO_ROSA",
  },
}

rewards = {
  gold = 320,
  items = {
    animal_treats = 10,
    lucky_clover = 2,
  },
}

meta = {
  giver = "farmer_rosa",
  location = "ZONE_CITY",
  tag = "HØST",
  category = "errand",
  repeatable = true,
  cooldown_days = 3,
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_ANIMAL_PRODUCTS_OFFER",
  }
end

function on_accept(context)
  api.set_flag("animal_products_active", true)
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("animal_products_active", false)
  end
end

function is_available(context)
  return not api.has_flag("animal_products_active")
end
