-- shops/seed_shop.lua
-- Kloevermyntes Froe (the guide's shop screen, plan 3.8: keeper merchant_pip = Butiksfe Kloevermynte) (P12).  kind = "shops".
--
-- shop fields: name_key, keeper (an npc id of lua/config/npcs.lua), greeting_key, buy_multiplier (what a shop charges: the
-- item's buy_price x this), sell_multiplier (what a shop pays: the item's sell_price x this; at least 1), stock.
-- stock = { item = { price?, stock, restock } }: `price` overrides the def's buy_price; `stock` is the most the shop holds;
-- `restock` is how many units come back every morning (up to `stock`; left out = the shelf is full again every morning).
-- Optional: tabs, buys, open_weekdays, rotation, price_curve (the home shops of lua/shops/home_shops.lua use all of them).
-- Without `tabs` ShopSystem builds the guide's tabs from the item categories: seed + farm = Froe, tool + weapon = Redskaber,
-- the rest = Varer, plus the sell tab.  The prices are the item defs' buy_prices: ONE number per item, never copied here.
--
-- The first eight lines are the guide's, in the guide's order: Gulerodsfroe 20, Graeskarfroe 60, Jordbaerfroe 45, Solsikkefroe 30,
-- Kattemyntefroe 35, Maanebonne 120 (moonflower_seeds), Goedning 15, Fe-stoev til marken 900 (fairy_dust_water).
--
-- Carrot seeds hold 25 (restock 25): a dedicated farm (110 plots after the 800 g field expansion) plants 110 / (4 / 0.85 + 1) = 19.2 carrots a day
-- and the shop is closed on Sundays, so the 6 open days have to carry 7 days: 6 x 25 = 150 a week = 21.4 a day (6 x 20 = 17.1 left 2.1 a day short).
-- economy_hours.seed_supply_covers_a_dedicated_field buys the shelf for a week through ShopSystem and checks it against that need.

kind = "shops"

shops = {
  seed_shop = {
    name_key = "SHOP_SEED_SHOP",
    keeper = "merchant_pip",
    greeting_key = "SHOP_SEED_SHOP_GREETING",
    buy_multiplier = 1.0,
    sell_multiplier = 1.0,
    stock = {
      carrot_seeds = { stock = 25, restock = 25 },       -- RT5: 6 open days x 25 = 150 a week = 21.4 a day covers a dedicated 110 plot field (19.2 a day; the shop is closed on Sundays)
      pumpkin_seeds = { stock = 15, restock = 15 },
      strawberry_seeds = { stock = 15, restock = 15 },
      sunflower_seeds = { stock = 15, restock = 15 },
      catnip_seeds = { stock = 15, restock = 15 },
      moonflower_seeds = { stock = 8, restock = 4 },
      fertilizer = { stock = 30, restock = 30 },
      fairy_dust_water = { stock = 3, restock = 1 },
      turnip_seeds = { stock = 30, restock = 30 },
      frost_kale_seeds = { stock = 20, restock = 20 },
      hoe_wooden = { stock = 2, restock = 1 },
      watering_can_copper = { stock = 2, restock = 1 },
      axe_wooden = { stock = 2, restock = 1 },
      pickaxe_wooden = { stock = 2, restock = 1 },
      scythe = { stock = 2, restock = 1 },
      fishing_rod = { stock = 2, restock = 1 },
    },
  },
}
