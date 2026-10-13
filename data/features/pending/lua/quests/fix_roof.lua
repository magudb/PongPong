-- quests/fix_roof.lua
-- Help a fairy citizen fix their mushroom-house roof after a storm.

-- FEATURES: rewards + a baker's hat (hat_chef_white) and friendship with Rosmarin.

kind = "quest"
id = "fix_roof"

objectives = {
  { id = "collect_wood", target = 8, description = "Saml 8 træstykker" },
  { id = "collect_moss", target = 4, description = "Saml 4 mos" },
  { id = "repair_roof", target = 1, description = "Reparer taget hos Fe-Byens bager" },
}

rewards = {
  gold = 320,
  items = { rare_mushroom = 1, friendship_token = 2, hat_chef_white = 1 },
  friendship = { baker_maja = 2 },
}

meta = {
  giver = "baker_maja",
  category = "help",
  repeatable = false,
  weather_trigger = "torden",
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_FIX_ROOF_OFFER",
  }
end

function on_accept(context)
  api.notification("Reparation", "Saml materialer til taget!")
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("maja_roof_fixed", true)
  end
end

function is_available(context)
  return not api.has_flag("maja_roof_fixed")
end
