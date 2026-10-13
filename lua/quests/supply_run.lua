-- quests/supply_run.lua
-- Pip needs supplies delivered around fairy city.

kind = "quest"
id = "supply_run"

objectives = {
  { id = "collect_wood", target = 10, description = "Saml 10 træ" },
  { id = "collect_stone", target = 6, description = "Saml 6 sten" },
  { id = "deliver_to_pip", target = 1, description = "Aflever til Pip" },
}

rewards = {
  gold = 200,
  items = {
    turnip_seeds = 10,
    carrot_seeds = 5,
  },
}

meta = {
  giver = "merchant_pip",
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
    api.add_gold(30) -- tip
  end
end

function is_available(context)
  return not api.has_flag("supply_run_active")
end
