-- quests/birthday_cake.lua
-- Baker-fairy Rosmarin bakes a birthday cake for a friend and is short of turnips and a moonflower.  Collect them and hand them over: the
-- delivery takes the goods out of the backpack.  The vocabulary is documented in quests/lost_cat.lua.

kind = "quest"
id = "birthday_cake"

objectives = {
  {
    id = "collect_turnip",
    target = 3,
    on = "item_gained",
    item = "turnip",
    have = true,
    description_key = "OBJ_BIRTHDAY_CAKE_COLLECT_TURNIP",
  },
  {
    id = "collect_moonflower",
    target = 1,
    on = "item_gained",
    item = "moonflower",
    have = true,
    description_key = "OBJ_BIRTHDAY_CAKE_COLLECT_MOONFLOWER",
  },
  {
    id = "deliver_cake",
    target = 1,
    on = "dialogue_started",
    npc = "baker_maja",
    after_others = true,
    needs = { turnip = 3, moonflower = 1 },
    consume = true,
    description_key = "OBJ_BIRTHDAY_CAKE_DELIVER_CAKE",
  },
}

rewards = {
  gold = 280,
  items = { cookie = 5, friendship_token = 2, lucky_clover = 1, plant_teapot_bonsai = 1 },
  friendship = { baker_maja = 2 },
}

meta = {
  giver = "baker_maja",
  location = "ZONE_CITY",
  tag = "HØST",
  category = "help",
  repeatable = false,
  cooldown_days = 0,
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_BIRTHDAY_CAKE_OFFER",
  }
end

function on_accept(context)
  api.set_flag("birthday_cake_active", true)
  api.notification("LUANOTIF_BIRTHDAY_CAKE_ACCEPT_TITLE", "LUANOTIF_BIRTHDAY_CAKE_ACCEPT_TEXT")
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("birthday_cake_active", false)
    api.set_flag("maja_birthday_done", true)
  end
end

function is_available(context)
  return not api.has_flag("maja_birthday_done")
end
