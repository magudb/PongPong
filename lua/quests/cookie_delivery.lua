-- quests/cookie_delivery.lua
-- Baker-fairy Rosmarin is out of carrots for her cookies (style guide: card "Bagerfe Rosmarin - 5 / 12").  Twelve carrots, then back to the
-- bakery: the delivery takes the carrots out of the backpack.  Repeatable after the cooldown.  The vocabulary is documented in quests/lost_cat.lua.

kind = "quest"
id = "cookie_delivery"

objectives = {
  {
    id = "collect_carrot",
    target = 12,
    on = "item_gained",
    item = "carrot",
    have = true,
    description_key = "OBJ_COOKIE_DELIVERY_COLLECT_CARROT",
  },
  {
    id = "deliver_to_baker",
    target = 1,
    on = "dialogue_started",
    npc = "baker_maja",
    after_others = true,
    needs = { carrot = 12 },
    consume = true,
    description_key = "OBJ_COOKIE_DELIVERY_DELIVER_TO_BAKER",
  },
}

rewards = {
  gold = 230,
  items = {
    cookie = 3,
    fairy_dust = 1,
  },
}

meta = {
  giver = "baker_maja",
  location = "ZONE_CITY",
  tag = "HØST",
  category = "errand",
  repeatable = true,
  cooldown_days = 3,
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_COOKIE_DELIVERY_OFFER",
  }
end

function on_accept(context)
  api.set_flag("cookie_delivery_active", true)
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("cookie_delivery_active", false)
  end
end

function is_available(context)
  return not api.has_flag("cookie_delivery_active")
end
