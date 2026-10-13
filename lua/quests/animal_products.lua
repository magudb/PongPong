-- quests/animal_products.lua
-- Collect animal products for Rosa's market stall.

kind = "quest"
id = "animal_products"

objectives = {
  { id = "collect_egg", target = 5, description = "Saml 5 æg" },
  { id = "collect_milk", target = 3, description = "Saml 3 mælk" },
  { id = "deliver_to_rosa", target = 1, description = "Aflever produkter til Rosa" },
}

rewards = {
  gold = 280,
  items = {
    animal_treats = 10,
    lucky_clover = 2,
  },
}

meta = {
  giver = "farmer_rosa",
  category = "errand",
  repeatable = true,
  cooldown_days = 3,
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_ANIMAL_PRODUCTS_OFFER",
  }
end

function on_accept(context)
  api.set_flag("animal_products_active", true)
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("animal_products_active", false)
    api.add_gold(40) -- tip
  end
end

function is_available(context)
  return not api.has_flag("animal_products_active")
end
