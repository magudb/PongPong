-- shops/lantern_house.lua
-- Natlys' Lygtehus (keeper ghostfam_gnist): the EVENING shop of the ghost family in the Gaestehytten of Traetoppen, open 17:00-01:00 (game hours 17-25), closed Wednesday (lua/buildings/ghostfam.lua).
-- kind = "shops"; the fields are explained in seed_shop.lua and home_shops.lua.  Only EXISTING items (no new item id, no new icon): lantern oil at the item's own price (the magic store charges 10 percent
-- more), the health tonic, and a daily rotation of two normal lamps; the shop BUYS forage at 125 percent (glow mushrooms and night blooms of the dark forest), nothing else.
-- NOT stocked on purpose: glow_mushroom (7 of them + 5 iron ore + 1 moonstone make a mushroom_lantern that sells for 300: lua/recipes/guide_recipes.lua), lantern_post (a placed lantern post is a PointLight2D
-- of the farm's light budget).  design5 scripts/economy_check.py proves both; design6 scripts/economy_check6.py re-proves them and the hide-and-seek ladder.

kind = "shops"

shops = {
  lantern_house = {
    name_key = "SHOP_LANTERN_HOUSE",
    keeper = "ghostfam_gnist",
    greeting_key = "SHOP_LANTERN_HOUSE_GREETING",
    buy_multiplier = 1.0,
    sell_multiplier = 1.25,
    buys = { "forage" },
    tabs = {
      { id = "dark", name_key = "SHOPTAB_LANTERN_DARK", categories = { "consumable" } },
      { id = "light", name_key = "SHOPTAB_LANTERN_LIGHT", furniture_types = { "lamp" } },
    },
    stock = {
      lantern_oil = { stock = 30, restock = 30 },
      health_tonic = { stock = 8, restock = 4 },
    },
    rotation = {
      {
        id = "dagens_lys",
        period = 1,
        pick = 2,
        qty = 2,
        rarity = "normal",
        price_mult = 1.0,
        season_boost = 1.0,
        pool = { "floor_lamp_birch", "floor_lamp_iron", "candelabra_iron", "sconce_iron", "table_lamp_clay", "chandelier_iron" },
      },
    },
  },
}
