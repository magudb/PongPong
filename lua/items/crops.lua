-- items/crops.lua
-- Crop and seed definitions for the treetop farm.

kind = "items"

items = {
  turnip_seeds = {
    name_key = "ITEM_TURNIP_SEEDS",
    category = "seed",
    crop_id = "turnip",
    buy_price = 20,
    sell_price = 5,
    description_key = "ITEM_TURNIP_SEEDS_DESC",
  },
  turnip = {
    name_key = "ITEM_TURNIP",
    category = "crop",
    buy_price = 0,
    sell_price = 45,
    description_key = "ITEM_TURNIP_DESC",
  },
  carrot_seeds = {
    name_key = "ITEM_CARROT_SEEDS",
    category = "seed",
    crop_id = "carrot",
    buy_price = 30,
    sell_price = 8,
    description_key = "ITEM_CARROT_SEEDS_DESC",
  },
  carrot = {
    name_key = "ITEM_CARROT",
    category = "crop",
    buy_price = 0,
    sell_price = 65,
    description_key = "ITEM_CARROT_DESC",
  },
  moonflower_seeds = {
    name_key = "ITEM_MOONFLOWER_SEEDS",
    category = "seed",
    crop_id = "moonflower",
    buy_price = 80,
    sell_price = 20,
    description_key = "ITEM_MOONFLOWER_SEEDS_DESC",
  },
  moonflower = {
    name_key = "ITEM_MOONFLOWER",
    category = "crop",
    buy_price = 0,
    sell_price = 180,
    description_key = "ITEM_MOONFLOWER_DESC",
  },
  pumpkin_seeds = {
    name_key = "ITEM_PUMPKIN_SEEDS",
    category = "seed",
    crop_id = "pumpkin",
    buy_price = 50,
    sell_price = 12,
    description_key = "ITEM_PUMPKIN_SEEDS_DESC",
  },
  pumpkin = {
    name_key = "ITEM_PUMPKIN",
    category = "crop",
    buy_price = 0,
    sell_price = 120,
    description_key = "ITEM_PUMPKIN_DESC",
  },
}
