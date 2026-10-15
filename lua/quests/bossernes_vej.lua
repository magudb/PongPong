-- DR7: explicit event bindings; progress and cooldowns belong to QuestManager.
kind = "quest"
id = "bossernes_vej"
objectives = {
  {
    id = "snurresvamp",
    target = 1,
    description_key = "OBJ_BOSSERNES_VEJ_SNURRESVAMP",
    on = "enemy_defeated",
    kind = "snurresvamp",
  },
  {
    id = "snurresvamp_gloed",
    target = 1,
    description_key = "OBJ_BOSSERNES_VEJ_SNURRESVAMP_GLOED",
    on = "enemy_defeated",
    kind = "snurresvamp_gloed",
  },
  {
    id = "snurresvamp_konge",
    target = 1,
    description_key = "OBJ_BOSSERNES_VEJ_SNURRESVAMP_KONGE",
    on = "enemy_defeated",
    kind = "snurresvamp_konge",
  },
  {
    id = "report",
    target = 1,
    on = "dialogue_started",
    npc = "guard_oak",
    after_others = true,
    description_key = "OBJ_BOSSERNES_VEJ_REPORT",
  },
}
rewards = {
  gold = 800,
  items = {
    fairy_dust = 5,
    gem_bag = 2,
  },
}
meta = {
  giver = "guard_oak",
  location = "ZONE_TRAETOPPEN",
  tag = "SKOV",
  category = "adventure",
  repeatable = false,
  cooldown_days = 0,
}

function on_offer(context)
  return { available = true, text_key = "QUEST_BOSSERNES_VEJ_OFFER" }
end

function on_accept(context)
  return { ok = true }
end

function is_available(context)
  return true
end
