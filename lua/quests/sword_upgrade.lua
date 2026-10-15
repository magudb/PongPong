-- quests/sword_upgrade.lua
-- Smith Thorin can forge your sword anew: three iron ingots (smelted at the forge from the ore of the Dark Wood) and a little fairy dust, handed
-- over to him (the delivery takes the goods out of the backpack).  Offered once the player has been in the wood (meta.requires_zone).
-- The vocabulary is documented in quests/lost_cat.lua.

kind = "quest"
id = "sword_upgrade"

objectives = {
  {
    id = "collect_iron_ingots",
    target = 3,
    on = "item_gained",
    item = "iron_ingot",
    have = true,
    description_key = "OBJ_SWORD_UPGRADE_COLLECT_IRON_INGOTS",
  },
  {
    id = "collect_fairy_dust",
    target = 1,
    on = "item_gained",
    item = "fairy_dust",
    have = true,
    description_key = "OBJ_SWORD_UPGRADE_COLLECT_FAIRY_DUST",
  },
  {
    id = "deliver_to_smith",
    target = 1,
    on = "dialogue_started",
    npc = "smith_thorin",
    after_others = true,
    needs = { iron_ingot = 3, fairy_dust = 1 },
    consume = true,
    description_key = "OBJ_SWORD_UPGRADE_DELIVER_TO_SMITH",
  },
}

rewards = {
  gold = 400,
  items = {
    iron_sword = 1,
  },
}

meta = {
  giver = "smith_thorin",
  location = "ZONE_CITY",
  tag = "BYG",
  category = "adventure",
  repeatable = false,
  cooldown_days = 0,
  requires_zone = "dark_forest",
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_SWORD_UPGRADE_OFFER",
  }
end

function on_accept(context)
  api.set_flag("sword_upgrade_active", true)
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("sword_upgrade_active", false)
    api.set_flag("has_iron_sword", true)
  end
end

function is_available(context)
  return not api.has_flag("has_iron_sword")
end
