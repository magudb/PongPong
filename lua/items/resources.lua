-- items/resources.lua
-- Mining, foraging, and adventure loot.

kind = "items"

items = {
  wood = {
    name_key = "ITEM_WOOD",
    category = "resource",
    buy_price = 5,
    sell_price = 2,
    description_key = "ITEM_WOOD_DESC",
  },
  stone = {
    name_key = "ITEM_STONE",
    category = "resource",
    buy_price = 4,
    sell_price = 1,
    description_key = "ITEM_STONE_DESC",
  },
  moss = {
    name_key = "ITEM_MOSS",
    category = "forage",
    buy_price = 8,
    sell_price = 3,
    description_key = "ITEM_MOSS_DESC",
  },
  iron_ore = {
    name_key = "ITEM_IRON_ORE",
    category = "mineral",
    buy_price = 40,
    sell_price = 15,
    description_key = "ITEM_IRON_ORE_DESC",
  },
  gold_ore = {
    name_key = "ITEM_GOLD_ORE",
    category = "mineral",
    buy_price = 100,
    sell_price = 45,
    description_key = "ITEM_GOLD_ORE_DESC",
  },
  amethyst = {
    name_key = "ITEM_AMETHYST",
    category = "gem",
    rarity = "uncommon",
    buy_price = 200,
    sell_price = 90,
    description_key = "ITEM_AMETHYST_DESC",
  },
  emerald = {
    name_key = "ITEM_EMERALD",
    category = "gem",
    rarity = "rare",
    buy_price = 450,
    sell_price = 200,
    description_key = "ITEM_EMERALD_DESC",
  },
  fairy_dust = {
    name_key = "ITEM_FAIRY_DUST",
    category = "magic",
    rarity = "rare",
    buy_price = 300,
    sell_price = 150,
    description_key = "ITEM_FAIRY_DUST_DESC",
  },
  rare_mushroom = {
    name_key = "ITEM_RARE_MUSHROOM",
    category = "forage",
    rarity = "uncommon",
    buy_price = 80,
    sell_price = 35,
    description_key = "ITEM_RARE_MUSHROOM_DESC",
  },
  lucky_clover = {
    name_key = "ITEM_LUCKY_CLOVER",
    category = "forage",
    rarity = "uncommon",
    buy_price = 60,
    sell_price = 25,
    description_key = "ITEM_LUCKY_CLOVER_DESC",
  },
  cookie = {
    name_key = "ITEM_COOKIE",
    category = "food",
    buy_price = 25,
    sell_price = 10,
    description_key = "ITEM_COOKIE_DESC",
  },
  friendship_token = {
    name_key = "ITEM_FRIENDSHIP_TOKEN",
    category = "special",
    buy_price = 0,
    sell_price = 0,
    description_key = "ITEM_FRIENDSHIP_TOKEN_DESC",
  },
}
