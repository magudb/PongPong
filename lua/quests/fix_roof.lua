-- quests/fix_roof.lua
-- The storm loosened the roof of the bakery.  Eight wood and four moss, then patch the roof at the bakery (the quest_spot of hyggebyen.map takes
-- exactly these goods: needs=wood:8,moss:4 consume=1; the same numbers stand in `needs` below, tests/sections/quests.gd keeps the two equal).
-- The vocabulary is documented in quests/lost_cat.lua.

kind = "quest"
id = "fix_roof"

objectives = {
  {
    id = "collect_wood",
    target = 8,
    on = "item_gained",
    item = "wood",
    have = true,
    description_key = "OBJ_FIX_ROOF_COLLECT_WOOD",
  },
  {
    id = "collect_moss",
    target = 4,
    on = "item_gained",
    item = "moss",
    have = true,
    description_key = "OBJ_FIX_ROOF_COLLECT_MOSS",
  },
  {
    id = "repair_roof",
    target = 1,
    on = "manual",
    needs = { wood = 8, moss = 4 },
    consume = true,
    description_key = "OBJ_FIX_ROOF_REPAIR_ROOF",
  },
}

rewards = {
  gold = 320,
  items = { rare_mushroom = 1, friendship_token = 2, hat_chef_white = 1 },
  friendship = { baker_maja = 2 },
}

meta = {
  giver = "mayor_lyra",
  location = "ZONE_CITY",
  tag = "BYG",
  category = "help",
  repeatable = false,
  cooldown_days = 0,
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_FIX_ROOF_OFFER",
  }
end

function on_accept(context)
  api.notification("LUANOTIF_FIX_ROOF_ACCEPT_TITLE", "LUANOTIF_FIX_ROOF_ACCEPT_TEXT")
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("maja_roof_fixed", true)
  end
end

function is_available(context)
  return not api.has_flag("maja_roof_fixed")
end
