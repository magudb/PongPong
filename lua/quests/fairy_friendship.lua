-- quests/fairy_friendship.lua
-- Long-term quest: earn friendship tokens by helping citizens.

kind = "quest"
id = "fairy_friendship"

objectives = {
  { id = "help_citizens", target = 3, description = "Hjælp 3 fe-borgere" },
  { id = "earn_friendship", target = 5, description = "Optjen 5 venskabstegn" },
  { id = "collect_fairy_dust", target = 2, description = "Saml 2 fe-støv" },
}

rewards = {
  gold = 500,
  items = {
    fairy_dust = 5,
    lucky_clover = 3,
  },
}

meta = {
  giver = "mayor_lyra",
  category = "friendship",
  repeatable = true,
  cooldown_days = 14,
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_FAIRES_FRIENDSHIP_OFFER",
  }
end

function on_accept(context)
  api.set_flag("fairy_friendship_active", true)
  api.notification("Feernes Venskab", "Bliv venner med fe-borgerne!")
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("fairy_friendship_active", false)
    api.set_flag("fairy_friendship_level", 1)
    api.add_gold(100) -- reputation bonus
  end
end

function is_available(context)
  return not api.has_flag("fairy_friendship_active")
end
