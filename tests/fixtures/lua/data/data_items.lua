-- tests/fixtures/lua/data/data_items.lua
-- An items file outside lua/items: still registered by its kind header (data.kinds_shops_recipes).
-- The categories furniture / clothing decide where an item lives (ItemKinds.storage_of), the rarity how it sorts.

kind = "items"

items = {
  fixture_widget = {
    name_key = "ITEM_FIXTURE_WIDGET",
    category = "special",
    rarity = "rare",
    buy_price = 10,
    sell_price = 4,
    perks = { speed = 0.05 },
  },
  fixture_stool = {
    name_key = "ITEM_FIXTURE_STOOL",
    category = "furniture",
    buy_price = 150,
    sell_price = 60,
  },
  fixture_chair = {
    name_key = "ITEM_FIXTURE_CHAIR",
    category = "furniture",
    rarity = "rare",
    buy_price = 1600,
    sell_price = 600,
  },
  fixture_throne = {
    name_key = "ITEM_FIXTURE_THRONE",
    category = "furniture",
    rarity = "unique",
    buy_price = 0,
    sell_price = 0,
    protected = true,
  },
  fixture_hat = {
    name_key = "ITEM_FIXTURE_HAT",
    category = "clothing",
    rarity = "legendary",
    buy_price = 0,
    sell_price = 0,
    slot = "hat",
  },
  fixture_seed = {
    name_key = "ITEM_FIXTURE_SEED",
    category = "seed",
    rarity = "common",
    crop_id = "turnip",
  },
}
