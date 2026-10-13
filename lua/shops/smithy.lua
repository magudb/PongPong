-- shops/smithy.lua
-- Smeden Thorins smedje (keeper smith_thorin) (P12).  kind = "shops"; the fields are explained in seed_shop.lua.
-- Iron tools and the iron sword: the upgrades of the starter kit (hoe 1 -> 2, watering can 1 -> 2, pickaxe -> 3, sword 5 -> 12).

kind = "shops"

shops = {
  smithy = {
    name_key = "SHOP_SMITHY",
    keeper = "smith_thorin",
    greeting_key = "SHOP_SMITHY_GREETING",
    buy_multiplier = 1.0,
    sell_multiplier = 1.0,
    stock = {
      hoe_iron = { stock = 2, restock = 1 },
      pickaxe_iron = { stock = 2, restock = 1 },
      watering_can_gold = { stock = 1, restock = 1 },
      iron_sword = { stock = 1, restock = 1 },
    },
  },
}
