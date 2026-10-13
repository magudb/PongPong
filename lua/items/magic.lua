-- items/magic.lua
-- Magic items, potions, and enchanted materials.

kind = "items"

items = {
  fairy_dust = {
    name_key = "ITEM_FAIRY_DUST",
    category = "magic",
    rarity = "rare",
    buy_price = 300,
    sell_price = 150,
    description_key = "ITEM_FAIRY_DUST_DESC",
  },
  crystal_shard = {
    name_key = "ITEM_CRYSTAL_SHARD",
    category = "gem",
    rarity = "uncommon",
    buy_price = 120,
    sell_price = 55,
    description_key = "ITEM_CRYSTAL_SHARD_DESC",
  },
  magic_scroll = {
    name_key = "ITEM_MAGIC_SCROLL",
    category = "magic",
    rarity = "uncommon",
    buy_price = 250,
    sell_price = 100,
    description_key = "ITEM_MAGIC_SCROLL_DESC",
  },
  mana_potion = {
    name_key = "ITEM_MANA_POTION",
    category = "consumable",
    buy_price = 120,
    sell_price = 50,
    description_key = "ITEM_MANA_POTION_DESC",
  },
  teleport_stone = {
    name_key = "ITEM_TELEPORT_STONE",
    category = "magic",
    rarity = "rare",
    buy_price = 400,
    sell_price = 180,
    description_key = "ITEM_TELEPORT_STONE_DESC",
  },
  enchanted_soil = {
    name_key = "ITEM_ENCHANTED_SOIL",
    category = "farm",
    buy_price = 180,
    sell_price = 70,
    description_key = "ITEM_ENCHANTED_SOIL_DESC",
  },
  glow_berry_seeds = {
    name_key = "ITEM_GLOW_BERRY_SEEDS",
    category = "seed",
    crop_id = "glow_berry",
    buy_price = 95,
    sell_price = 30,
    description_key = "ITEM_GLOW_BERRY_SEEDS_DESC",
  },
  glow_berry = {
    name_key = "ITEM_GLOW_BERRY",
    category = "crop",
    rarity = "uncommon",
    buy_price = 0,
    sell_price = 150,
    description_key = "ITEM_GLOW_BERRY_DESC",
  },
}
