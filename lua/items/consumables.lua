-- items/consumables.lua
-- Potions, lantern oil and the cookie (P12; health_tonic and lantern_oil come from the 2D world spike).
-- Effects are fields of the def and are applied by the player (EconomyManager.use_item / Player2D drink, R):
--   heal_half_hearts  half hearts restored      oil_seconds  seconds of lantern oil added      stamina  energy restored
-- stamina_cost is 0: drinking never costs energy.  (More effect items: mana_potion in magic.lua, apple in resources.lua,
-- honey_cake in crafted.lua.)

kind = "items"

items = {
  health_tonic = {
    name_key = "ITEM_HEALTH_TONIC",
    description_key = "ITEM_HEALTH_TONIC_DESC",
    category = "consumable",
    heal_half_hearts = 4,
    stamina_cost = 0,
    rarity = "normal",
    max_stack = 20,
    buy_price = 60,
    sell_price = 20,
  },
  lantern_oil = {
    name_key = "ITEM_LANTERN_OIL",
    description_key = "ITEM_LANTERN_OIL_DESC",
    category = "consumable",
    oil_seconds = 60,
    stamina_cost = 0,
    rarity = "normal",
    max_stack = 99,
    buy_price = 25,
    sell_price = 8,
  },
  cookie = {
    name_key = "ITEM_COOKIE",
    description_key = "ITEM_COOKIE_DESC",
    category = "food",
    stamina = 15,
    stamina_cost = 0,
    rarity = "normal",
    max_stack = 99,
    buy_price = 25,
    sell_price = 10,
  },
}
