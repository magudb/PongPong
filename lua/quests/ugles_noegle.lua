-- DR7: explicit event bindings; progress and cooldowns belong to QuestManager.
kind = "quest"
id = "ugles_noegle"
objectives = {
  {
    id = "amethyst",
    target = 1,
    description_key = "OBJ_UGLES_NOEGLE_AMETHYST",
    on = "item_gained",
    item = "amethyst",
    have = true,
  },
  {
    id = "rose_quartz",
    target = 1,
    description_key = "OBJ_UGLES_NOEGLE_ROSE_QUARTZ",
    on = "item_gained",
    item = "rose_quartz",
    have = true,
  },
  {
    id = "amber",
    target = 1,
    description_key = "OBJ_UGLES_NOEGLE_AMBER",
    on = "item_gained",
    item = "amber",
    have = true,
  },
  {
    id = "deliver",
    target = 1,
    on = "dialogue_started",
    npc = "appraiser_fru_ugle",
    after_others = true,
    description_key = "OBJ_UGLES_NOEGLE_REPORT",
    needs = {
      amethyst = 1,
      rose_quartz = 1,
      amber = 1,
    },
    consume = true,
  },
}
rewards = {
  gold = 150,
  items = {
    ugle_noegle = 1,
  },
}
meta = {
  giver = "appraiser_fru_ugle",
  location = "ZONE_TRAETOPPEN",
  tag = "SKOV",
  category = "adventure",
  repeatable = true,
  cooldown_days = 7,
}

function on_offer(context)
  return { available = true, text_key = "QUEST_UGLES_NOEGLE_OFFER" }
end

function on_accept(context)
  return { ok = true }
end

function is_available(context)
  return true
end
