-- shops/bakery.lua
-- Bagerfe Rosmarins bageri (keeper baker_maja) (P12).  kind = "shops"; the fields are explained in seed_shop.lua.
-- Flour and honey are bought here: the game has no wheat crop and no beehive (the guide's "Mangler mel" is flour).
-- With an egg of the farm they become the guide's Honningkage (recipe honey_cake, category bake).

kind = "shops"

shops = {
  bakery = {
    name_key = "SHOP_BAKERY",
    keeper = "baker_maja",
    greeting_key = "SHOP_BAKERY_GREETING",
    buy_multiplier = 1.0,
    sell_multiplier = 1.0,
    stock = {
      flour = { stock = 20, restock = 20 },
      honey = { stock = 10, restock = 10 },
      cookie = { stock = 12, restock = 12 },
    },
  },
}
