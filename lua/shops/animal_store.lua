-- shops/animal_store.lua
-- Dyrehandler Rosas butik (keeper farmer_rosa) (P12).  kind = "shops"; the fields are explained in seed_shop.lua.
-- Baby animals, feed, the brush and the milking pail: ONLY ids of lua/items/animals.lua (P20 owns that file and its prices).
-- coop_kit and barn_kit are gone: the buildings come from the build menu (B), not from a shop.

kind = "shops"

shops = {
  animal_store = {
    name_key = "SHOP_ANIMAL_STORE",
    keeper = "farmer_rosa",
    greeting_key = "SHOP_ANIMAL_STORE_GREETING",
    buy_multiplier = 1.0,
    sell_multiplier = 1.0,
    stock = {
      baby_chick = { stock = 5, restock = 1 },
      baby_bunny = { stock = 5, restock = 1 },
      baby_duck = { stock = 4, restock = 1 },
      baby_kitten = { stock = 3, restock = 1 },
      baby_puppy = { stock = 3, restock = 1 },
      baby_lamb = { stock = 3, restock = 1 },
      baby_calf = { stock = 2, restock = 1 },
      baby_fawn = { stock = 2, restock = 1 },
      baby_fox = { stock = 1, restock = 1 },
      baby_owl = { stock = 1, restock = 1 },
      chicken_feed = { stock = 30, restock = 30 },
      animal_treats = { stock = 20, restock = 20 },
      brush = { stock = 5, restock = 2 },
      milking_pail = { stock = 3, restock = 1 },
    },
  },
}
