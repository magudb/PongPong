-- shops/timber_yard.lua
-- Brumme's farm-timber shop (package V1-cast-data): the building materials a farm needs, at the prices of the item definitions
-- (ONE price per item: no `price` override here, the defs of lua/items/resources.lua and building_materials.lua decide).  kind = "shops".
-- The keeper is carpenter_brumme (his npcs.lua row names shop_id = "timber_yard").  Brumme sells at his workshop Monday to Friday and at his
-- Torvet stall on Saturday and Sunday; the opening hours are the buildings registry of the towns track, not this file.
--
-- Hasselnoeds builder_yard (lua/shops/home_shops.lua: home upgrades, fine goods, a daily rotation) is a DIFFERENT shop with another
-- keeper and stays untouched: this one has a plain fixed stock and no rotation.
--
-- shop fields: see lua/shops/seed_shop.lua.  `buys` = the item categories the keeper takes back (the sell tab); stock = the most the
-- shop holds, restock = how many units come back every morning (here: the full stock).

kind = "shops"

shops = {
  timber_yard = {
    name_key = "SHOP_TIMBER_YARD",
    keeper = "carpenter_brumme",
    greeting_key = "SHOP_TIMBER_YARD_GREETING",
    buy_multiplier = 1.0,
    sell_multiplier = 1.0,
    buys = { "building_material", "resource" },
    stock = {
      wood = { stock = 60, restock = 60 },
      stone = { stock = 60, restock = 60 },
      plank_pine = { stock = 30, restock = 30 },
      timber_beam = { stock = 20, restock = 20 },
      nails = { stock = 40, restock = 40 },
      rope = { stock = 20, restock = 20 },
      straw_bundle = { stock = 20, restock = 20 },
    },
  },
}
