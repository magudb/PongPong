-- quests/snurresvampen.lua
-- Boss quest.  First-kill legendary: the Spinner Hat.  Gate of home tier 8.  Offered by Guard Oak (dialogue guard_oak, quest_accept).
-- enter_dybe_bregner listens to EventBus.area_changed(area_id): the map id dybe_bregner (its @zone is dark_forest, shared with skovkant).

kind = "quest"
id = "snurresvampen"

objectives = {
  {
    id = "enter_dybe_bregner",
    target = 1,
    on = "area_changed",
    area = "dybe_bregner",
    description_key = "OBJ_SNURRESVAMPEN_ENTER_DYBE_BREGNER",
  },
  {
    id = "defeat_snurresvampen",
    target = 1,
    on = "enemy_defeated",
    kind = "snurresvamp",
    description_key = "OBJ_SNURRESVAMPEN_DEFEAT_SNURRESVAMPEN",
  },
  {
    id = "return_to_oak",
    target = 1,
    on = "dialogue_started",
    npc = "guard_oak",
    after_others = true,
    description_key = "OBJ_SNURRESVAMPEN_RETURN_TO_OAK",
  },
}

rewards = {
  gold = 1200,
  items = { hat_mushroom_spinner = 1, fairy_dust = 3 },
  friendship = { guard_oak = 2 },
}

meta = {
  giver = "guard_oak",
  location = "ZONE_DYBE_BREGNER",
  tag = "SKOV",
  category = "adventure",
  repeatable = false,
  cooldown_days = 0,
  requires_zone = "dark_forest",
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_SNURRESVAMPEN_OFFER",
  }
end

function on_accept(context)
  api.set_flag("snurresvampen_active", true)
  api.notification("QUEST_SNURRESVAMPEN_ACCEPT_TITLE", "QUEST_SNURRESVAMPEN_ACCEPT_TEXT")
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("snurresvampen_active", false)
    api.set_flag("snurresvampen_done", true)
    api.notification("QUEST_SNURRESVAMPEN_DONE_TITLE", "QUEST_SNURRESVAMPEN_DONE_TEXT")
  end
end

function is_available(context)
  return not api.has_flag("snurresvampen_done")
end
