-- tests/fixtures/lua/shops_extra.lua
-- kind = "shops" with every extra field the home shops use: tabs (furniture_types / slots / groups / categories), buys,
-- open_weekdays, rotation (pools, periods, picks), price_curve (nested tables and arrays of tables, empty `sales`), stock.
-- LuaRuntime must hand all of it through untouched (data.kinds_shops_recipes_passthrough).

kind = "shops"

shops = {
  fixture_furniture = {
    name_key = "SHOP_FIXTURE_FURNITURE",
    keeper = "fairy_furnisher",
    greeting_key = "SHOP_FIXTURE_FURNITURE_GREETING",
    buy_multiplier = 1.0,
    sell_multiplier = 0.5,
    buys = { "furniture", "clothing" },
    open_weekdays = { 5, 6 },
    tabs = {
      { id = "sleep", name_key = "SHOPTAB_FIXTURE_SLEEP", furniture_types = { "bed" } },
      { id = "living", name_key = "SHOPTAB_FIXTURE_LIVING", furniture_types = { "sofa", "chair", "table" } },
      { id = "hat", name_key = "SHOPTAB_FIXTURE_HAT", slots = { "hat", "circlet" } },
      { id = "timber", name_key = "SHOPTAB_FIXTURE_TIMBER", groups = { "timber" } },
      { id = "plans", name_key = "SHOPTAB_FIXTURE_PLANS", categories = { "blueprint" } },
    },
    stock = {
      bed_birch_single = { stock = 3, restock = 2 },
      chair_pine = { price = 120, stock = 4, restock = 1 },
    },
    rotation = {
      {
        id = "daily",
        period = 1,
        pick = 2,
        qty = 3,
        rarity = "normal",
        price_mult = 1.0,
        season_boost = 2.0,
        pool = { "bed_oak_single", "chair_oak", "table_long_pine" },
      },
      {
        id = "weekly",
        period = 7,
        pick = 1,
        qty = 1,
        rarity = "rare",
        price_mult = 1.1,
        season_boost = 1.0,
        pool = { "throne_king" },
      },
    },
    price_curve = {
      repeat_surcharge = { step = 0.08, max = 0.32 },
      friend_discount = { per_heart = 0.005, max_hearts = 10 },
      sales = {
        { id = "season_end", from_day = 22, to_day = 28, discount = 0.15, rarity = { "uncommon" } },
        { id = "spring_fair", from_day = 1, to_day = 3, discount = 0.1, rarity = { "normal", "uncommon" } },
      },
    },
  },
  fixture_minimal = {
    name_key = "SHOP_FIXTURE_MINIMAL",
    keeper = "merchant_pip",
    stock = {},
    price_curve = { sales = {} },
  },
}
