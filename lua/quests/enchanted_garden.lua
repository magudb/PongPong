-- quests/enchanted_garden.lua
-- Wake an enchanted garden with rare seeds: find the seeds, water the garden, plant enchanted crops.  Repeatable after the cooldown.
-- The vocabulary is documented in quests/lost_cat.lua.

kind = "quest"
id = "enchanted_garden"

objectives = {
  {
    id = "collect_rare_seeds",
    target = 3,
    on = "item_gained",
    item = "moonflower_seeds",
    have = true,
    description_key = "OBJ_ENCHANTED_GARDEN_COLLECT_RARE_SEEDS",
  },
  {
    id = "water_garden",
    target = 3,
    on = "crop_watered",
    description_key = "OBJ_ENCHANTED_GARDEN_WATER_GARDEN",
  },
  {
    id = "plant_enchanted",
    target = 2,
    on = "crop_planted",
    crop = "moonflower",
    description_key = "OBJ_ENCHANTED_GARDEN_PLANT_ENCHANTED",
  },
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
  location = "ZONE_FARM",
  tag = "HØST",
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
  api.notification("LUANOTIF_ENCHANTED_GARDEN_ACCEPT_TITLE", "LUANOTIF_ENCHANTED_GARDEN_ACCEPT_TEXT")
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("enchanted_garden_active", false)
    api.set_flag("enchanted_garden_unlocked", true)
  end
end

function is_available(context)
  return not api.has_flag("enchanted_garden_active")
end
