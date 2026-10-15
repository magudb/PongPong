-- quests/fairy_friendship.lua
-- Long-term quest: earn friendship by helping the citizens.  help_citizens counts every completed help / errand quest (on = "quest_completed",
-- category list); the friendship tokens and the fairy dust are owned goods (have = true).  Repeatable after the cooldown.
-- The vocabulary is documented in quests/lost_cat.lua.

kind = "quest"
id = "fairy_friendship"

objectives = {
  {
    id = "help_citizens",
    target = 3,
    on = "quest_completed",
    category = "help,errand",
    description_key = "OBJ_FAIRY_FRIENDSHIP_HELP_CITIZENS",
  },
  {
    id = "earn_friendship",
    target = 5,
    on = "item_gained",
    item = "friendship_token",
    have = true,
    description_key = "OBJ_FAIRY_FRIENDSHIP_EARN_FRIENDSHIP",
  },
  {
    id = "collect_fairy_dust",
    target = 2,
    on = "item_gained",
    item = "fairy_dust",
    have = true,
    description_key = "OBJ_FAIRY_FRIENDSHIP_COLLECT_FAIRY_DUST",
  },
}

rewards = {
  gold = 600,
  items = {
    fairy_dust = 5,
    lucky_clover = 3,
  },
}

meta = {
  giver = "mayor_lyra",
  location = "ZONE_CITY",
  tag = "VENSKAB",
  category = "friendship",
  repeatable = true,
  cooldown_days = 14,
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_FAIRY_FRIENDSHIP_OFFER",
  }
end

function on_accept(context)
  api.set_flag("fairy_friendship_active", true)
  api.notification("LUANOTIF_FAIRY_FRIENDSHIP_ACCEPT_TITLE", "LUANOTIF_FAIRY_FRIENDSHIP_ACCEPT_TEXT")
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("fairy_friendship_active", false)
    api.set_flag("fairy_friendship_level", 1)
  end
end

function is_available(context)
  return not api.has_flag("fairy_friendship_active")
end
