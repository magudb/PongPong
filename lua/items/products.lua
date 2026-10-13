-- items/products.lua
-- What the animals give (lua/items/animals.lua `produces`) and what the bakery sells (P12).
--   egg duck_egg (hen, duck)   wool (bunny, lamb)   milk (calf)   magic_herb (fawn)   lucky_fur (fox)   wisdom_feather (owl)
--   flour honey: bought at the bakery (there is no wheat crop and no beehive; the guide's "Mangler mel" is flour)
-- The kitten and the puppy used to "produce companionship": that product is the friendship_token now (resources.lua).
-- Category product (animals), food (flour, honey: ingredients of the bakery).  buy_price 0 = never sold by a shop.

kind = "items"

items = {
  egg = {
    name_key = "ITEM_EGG",
    description_key = "ITEM_EGG_DESC",
    category = "product",
    rarity = "normal",
    max_stack = 99,
    buy_price = 0,
    sell_price = 15,
  },
  duck_egg = {
    name_key = "ITEM_DUCK_EGG",
    description_key = "ITEM_DUCK_EGG_DESC",
    category = "product",
    rarity = "normal",
    max_stack = 99,
    buy_price = 0,
    sell_price = 25,
  },
  wool = {
    name_key = "ITEM_WOOL",
    description_key = "ITEM_WOOL_DESC",
    category = "product",
    rarity = "normal",
    max_stack = 99,
    buy_price = 30,
    sell_price = 12,
  },
  milk = {
    name_key = "ITEM_MILK",
    description_key = "ITEM_MILK_DESC",
    category = "product",
    rarity = "normal",
    max_stack = 99,
    buy_price = 0,
    sell_price = 35,
  },
  magic_herb = {
    name_key = "ITEM_MAGIC_HERB",
    description_key = "ITEM_MAGIC_HERB_DESC",
    category = "product",
    rarity = "uncommon",
    max_stack = 99,
    buy_price = 0,
    sell_price = 80,
  },
  lucky_fur = {
    name_key = "ITEM_LUCKY_FUR",
    description_key = "ITEM_LUCKY_FUR_DESC",
    category = "product",
    rarity = "uncommon",
    max_stack = 99,
    buy_price = 0,
    sell_price = 120,
  },
  wisdom_feather = {
    name_key = "ITEM_WISDOM_FEATHER",
    description_key = "ITEM_WISDOM_FEATHER_DESC",
    category = "product",
    rarity = "rare",
    max_stack = 99,
    buy_price = 0,
    sell_price = 200,
  },
  flour = {
    name_key = "ITEM_FLOUR",
    description_key = "ITEM_FLOUR_DESC",
    category = "food",
    rarity = "normal",
    max_stack = 99,
    buy_price = 12,
    sell_price = 5,
  },
  honey = {
    name_key = "ITEM_HONEY",
    description_key = "ITEM_HONEY_DESC",
    category = "food",
    rarity = "normal",
    max_stack = 99,
    buy_price = 30,
    sell_price = 12,
  },
}
