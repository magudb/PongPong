-- quests/flower_necklace.lua
-- Fairy child Lily wants a necklace of wild forest flowers: pick five wild flowers, craft the necklace (recipe flower_necklace), give it to Lily.
-- The delivery takes the necklace out of the backpack.  Repeatable after the cooldown.  The vocabulary is documented in quests/lost_cat.lua.

kind = "quest"
id = "flower_necklace"

objectives = {
  {
    id = "collect_flowers",
    target = 5,
    on = "item_gained",
    item = "wild_flower",
    have = true,
    description_key = "OBJ_FLOWER_NECKLACE_COLLECT_FLOWERS",
  },
  {
    id = "craft_necklace",
    target = 1,
    on = "recipe_crafted",
    recipe = "flower_necklace",
    description_key = "OBJ_FLOWER_NECKLACE_CRAFT_NECKLACE",
  },
  {
    id = "deliver_necklace",
    target = 1,
    on = "dialogue_started",
    npc = "fairy_lily",
    after_others = true,
    needs = { flower_necklace = 1 },
    consume = true,
    description_key = "OBJ_FLOWER_NECKLACE_DELIVER_NECKLACE",
  },
}

rewards = {
  gold = 120,
  items = {
    friendship_token = 2,
    lucky_clover = 1,
    fairy_dust = 1,
  },
}

meta = {
  giver = "fairy_lily",
  location = "ZONE_CITY",
  tag = "FIND",
  category = "help",
  repeatable = true,
  cooldown_days = 4,
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_FLOWER_NECKLACE_OFFER",
  }
end

function on_accept(context)
  api.set_flag("flower_necklace_active", true)
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("flower_necklace_active", false)
  end
end

function is_available(context)
  return not api.has_flag("flower_necklace_active")
end
