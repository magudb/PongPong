-- quests/cookie_delivery.lua
-- Fairy citizen needs crops for their cookie recipe.

kind = "quest"
id = "cookie_delivery"

objectives = {
  { id = "collect_turnip", target = 5, description = "Saml 5 majroe" },
  { id = "deliver_to_baker", target = 1, description = "Aflever majroer til bageren Maja" },
}

rewards = {
  gold = 180,
  items = {
    cookie = 3,
    fairy_dust = 1,
  },
}

meta = {
  giver = "baker_maja",
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
    api.add_gold(50) -- tip
  end
end

function is_available(context)
  return not api.has_flag("cookie_delivery_active")
end
