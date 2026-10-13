-- quests/flower_necklace.lua
-- Lily wants a flower necklace made from wild forest flowers.

kind = "quest"
id = "flower_necklace"

objectives = {
  { id = "collect_flowers", target = 5, description = "Saml 5 vilde blomster" },
  { id = "craft_necklace", target = 1, description = "Lav blomsterkransen" },
  { id = "deliver_necklace", target = 1, description = "Giv blomsterkransen til Lily" },
}

rewards = {
  gold = 120,
  items = {
    friendship_token = 2,
    lucky_clover = 1,
    fairy_dust = 1,
  },
}

meta = {
  giver = "fairy_lily",
  category = "help",
  repeatable = true,
  cooldown_days = 4,
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_FLOWER_NECKLACE_OFFER",
  }
end

function on_accept(context)
  api.set_flag("flower_necklace_active", true)
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("flower_necklace_active", false)
  end
end

function is_available(context)
  return not api.has_flag("flower_necklace_active")
end
