-- quests/rare_mushroom_hunt.lua
-- Fairy child Lily's little friend needs a glowing mushroom for medicine: collect four glowing mushrooms, find the glowing one in the Mushroom
-- Grove (find_glowing is a manual objective: the generator puts a quest_spot rare_mushroom_hunt / find_glowing on floor 7, DUNGEON_V2_ADDENDUM 2.7),
-- give the mushrooms to Lily.  The delivery takes them out of the backpack.  Repeatable after the cooldown.
-- The vocabulary is documented in quests/lost_cat.lua.

kind = "quest"
id = "rare_mushroom_hunt"

objectives = {
  {
    id = "collect_mushrooms",
    target = 4,
    on = "item_gained",
    item = "glow_mushroom",
    have = true,
    description_key = "OBJ_RARE_MUSHROOM_HUNT_COLLECT_MUSHROOMS",
  },
  {
    id = "find_glowing",
    target = 1,
    on = "manual",
    description_key = "OBJ_RARE_MUSHROOM_HUNT_FIND_GLOWING",
  },
  {
    id = "deliver_to_lily",
    target = 1,
    on = "dialogue_started",
    npc = "fairy_lily",
    after_others = true,
    needs = { glow_mushroom = 4 },
    consume = true,
    description_key = "OBJ_RARE_MUSHROOM_HUNT_DELIVER_TO_LILY",
  },
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
  location = "ZONE_MUSHROOM_GROVE",
  tag = "SKOV",
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
