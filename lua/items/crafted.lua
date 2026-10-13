-- items/crafted.lua
-- Things the Vaerksted makes (recipes: lua/recipes/guide_recipes.lua) (P12).
--   iron_ingot                         forge recipe (iron_ore x2); the smith's sword_upgrade quest asks for three
--   mushroom_lantern scarecrow lantern_post fence   placeable decorations of the farm: `placeable = "farm"`.  The hotbar
--     places them on a free cell (PlacementService, P20); they are DECORATIONS: the scarecrow scares no crows (plan 3.10)
--   honey_cake                         baked (recipe category bake: the hobbit's bake_bonus applies); eaten it restores energy
--   flower_necklace                    Lily's quest item (category quest: it cannot be sold)
-- buy_price 0: crafted things are never in a shop.  sell_price stays at or below the value of what went into them, except
-- honey_cake (the intended value-add of baking: eggs and flour become a cake worth more than they are).

kind = "items"

items = {
  iron_ingot = {
    name_key = "ITEM_IRON_INGOT",
    description_key = "ITEM_IRON_INGOT_DESC",
    category = "material",
    rarity = "normal",
    max_stack = 99,
    buy_price = 0,
    sell_price = 45,
  },
  mushroom_lantern = {
    name_key = "ITEM_MUSHROOM_LANTERN",
    description_key = "ITEM_MUSHROOM_LANTERN_DESC",
    category = "placeable",
    placeable = "farm",
    stamina_cost = 1.0,
    rarity = "uncommon",
    max_stack = 20,
    buy_price = 0,
    sell_price = 300,
  },
  scarecrow = {
    name_key = "ITEM_SCARECROW",
    description_key = "ITEM_SCARECROW_DESC",
    category = "placeable",
    placeable = "farm",
    stamina_cost = 1.0,
    rarity = "normal",
    max_stack = 20,
    buy_price = 0,
    sell_price = 12,
  },
  lantern_post = {
    name_key = "ITEM_LANTERN_POST",
    description_key = "ITEM_LANTERN_POST_DESC",
    category = "placeable",
    placeable = "farm",
    stamina_cost = 1.0,
    rarity = "normal",
    max_stack = 20,
    buy_price = 0,
    sell_price = 30,
  },
  fence = {
    name_key = "ITEM_FENCE",
    description_key = "ITEM_FENCE_DESC",
    category = "placeable",
    placeable = "farm",
    stamina_cost = 1.0,
    rarity = "normal",
    max_stack = 99,
    buy_price = 0,
    sell_price = 2,
  },
  honey_cake = {
    name_key = "ITEM_HONEY_CAKE",
    description_key = "ITEM_HONEY_CAKE_DESC",
    category = "food",
    stamina = 40,
    stamina_cost = 0,
    rarity = "uncommon",
    max_stack = 20,
    buy_price = 0,
    sell_price = 90,
  },
  flower_necklace = {
    name_key = "ITEM_FLOWER_NECKLACE",
    description_key = "ITEM_FLOWER_NECKLACE_DESC",
    category = "quest",
    rarity = "normal",
    max_stack = 1,
    buy_price = 0,
    sell_price = 0,
  },
}
