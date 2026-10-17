-- shops/magic_store.lua
-- Fe-troldmanden Zephyrs butik (keeper fairy_wizard) (P12).  kind = "shops"; the fields are explained in seed_shop.lua.
-- Fairy dust, gems, lantern oil and the health tonic; the wizard charges 10 percent more than the item's base price
-- (buy_multiplier 1.1) and pays the normal sell price.  glow_berry_seeds are the only seeds of the shop (the 8th crop).

kind = "shops"

shops = {
  magic_store = {
    name_key = "SHOP_MAGIC_STORE",
    keeper = "fairy_wizard",
    greeting_key = "SHOP_MAGIC_STORE_GREETING",
    buy_multiplier = 1.1,
    sell_multiplier = 1.0,
    stock = {
      moonstone = { stock = 1, restock = 1 },
      fairy_dust = { stock = 5, restock = 1 },
      crystal_shard = { stock = 5, restock = 2 },
      amethyst = { stock = 3, restock = 1 },
      emerald = { stock = 2, restock = 1 },
      lantern_oil = { stock = 20, restock = 20 },
      health_tonic = { stock = 10, restock = 5 },
      mana_potion = { stock = 6, restock = 3 },
      glow_berry_seeds = { stock = 8, restock = 4 },
    },
  },
}
