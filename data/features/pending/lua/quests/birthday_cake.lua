-- quests/birthday_cake.lua
-- Maja's birthday is coming — gather ingredients for a surprise cake.

-- FEATURES: rewards + the unique Bonsai in a Teapot (plant_teapot_bonsai).

kind = "quest"
id = "birthday_cake"

objectives = {
  { id = "collect_turnip", target = 3, description = "Saml 3 majroe" },
  { id = "collect_moonflower", target = 1, description = "Saml 1 måneblomst" },
  { id = "deliver_cake", target = 1, description = "Bag og lever kagen" },
}

rewards = {
  gold = 280,
  items = { cookie = 5, friendship_token = 2, lucky_clover = 1, plant_teapot_bonsai = 1 },
  friendship = { baker_maja = 2 },
}

meta = {
  giver = "baker_maja",
  category = "help",
  repeatable = false,
}

function on_offer(context)
  return {
    available = true,
    text_key = "QUEST_BIRTHDAY_CAKE_OFFER",
  }
end

function on_accept(context)
  api.set_flag("birthday_cake_active", true)
  api.notification("Fødselsdagskage", "Saml ingredienser til overraskelsen!")
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("birthday_cake_active", false)
    api.set_flag("maja_birthday_done", true)
  end
end

function is_available(context)
  return not api.has_flag("maja_birthday_done")
end
