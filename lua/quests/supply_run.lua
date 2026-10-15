-- quests/supply_run.lua
-- Shop-fairy Kloevermynte (merchant_pip) needs wood and stone for the shop: ten wood, six stone, delivered to her (the delivery takes the goods out
-- of the backpack).  Repeatable after the cooldown.  The vocabulary is documented in quests/lost_cat.lua.

kind = "quest"
id = "supply_run"

objectives = {
  {
    id = "collect_wood",
    target = 10,
    on = "item_gained",
    item = "wood",
    have = true,
    description_key = "OBJ_SUPPLY_RUN_COLLECT_WOOD",
  },
  {
    id = "collect_stone",
    target = 6,
    on = "item_gained",
    item = "stone",
    have = true,
    description_key = "OBJ_SUPPLY_RUN_COLLECT_STONE",
  },
  {
    id = "deliver_to_pip",
    target = 1,
    on = "dialogue_started",
    npc = "merchant_pip",
    after_others = true,
    needs = { wood = 10, stone = 6 },
    consume = true,
    description_key = "OBJ_SUPPLY_RUN_DELIVER_TO_PIP",
  },
}

rewards = {
  gold = 230,
  items = {
    turnip_seeds = 10,
    carrot_seeds = 5,
  },
}

meta = {
  giver = "merchant_pip",
  location = "ZONE_CITY",
  tag = "HØST",
  category = "errand",
  repeatable = true,
  cooldown_days = 2,
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_SUPPLY_RUN_OFFER",
  }
end

function on_accept(context)
  api.set_flag("supply_run_active", true)
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("supply_run_active", false)
  end
end

function is_available(context)
  return not api.has_flag("supply_run_active")
end
