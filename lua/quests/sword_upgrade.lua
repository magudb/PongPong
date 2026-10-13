-- quests/sword_upgrade.lua
-- Thorin can upgrade your sword with iron ingots from the dark forest.

kind = "quest"
id = "sword_upgrade"

objectives = {
  { id = "collect_iron_ingots", target = 3, description = "Saml 3 jernbarrer" },
  { id = "collect_fairy_dust", target = 1, description = "Saml 1 fe-støv" },
  { id = "deliver_to_smith", target = 1, description = "Aflever materialer til Thorin" },
}

rewards = {
  gold = 400,
  items = {
    iron_sword = 1,
  },
}

meta = {
  giver = "smith_thorin",
  category = "adventure",
  repeatable = false,
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
