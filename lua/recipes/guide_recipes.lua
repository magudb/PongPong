-- recipes/guide_recipes.lua
-- The Vaerksted recipes of the style guide (screen 09) and the quest recipes (P12).  kind = "recipes".
--
-- recipe fields: name_key (RECIPE_<ID>), category (craft | bake | forge), ingredients { item = amount }, output { item, amount }.
-- Optional (the home recipes of lua/recipes/furniture.lua use them, CraftingSystem reads all of them):
--   station          snedkerbord | vaev | smedje   a station of the home; it is unlocked by a home tier
--   min_home_tier    the home tier (world flag home_tier) the recipe needs
--   unlock_flag      a blueprint flag (bp_kongelig ...) that has to be set
-- The recipes below need no station, tier or blueprint: the Vaerksted of the backpack has them from the first day.
-- category bake: the hobbit's bake_bonus (race_perks.lua) gives one more output with that chance.
--
-- The guide: "Lygte med svampelys" (glow_mushroom 7, iron_ore 5, moonstone 1 - the guide shows 3 / 7, 1 / 5, 1 / 1),
-- "Honningkage" (flour 2, honey 1, egg 1 - "Mangler mel": flour is bought at the bakery), "Kobberhakke" (copper_ore 3,
-- wood 2 - "Mangler 2 kobber"), "Fugleskraemsel".

kind = "recipes"

recipes = {
  mushroom_lantern = {
    name_key = "RECIPE_MUSHROOM_LANTERN",
    category = "craft",
    ingredients = { glow_mushroom = 7, iron_ore = 5, moonstone = 1 },
    output = { item = "mushroom_lantern", amount = 1 },
  },
  scarecrow = {
    name_key = "RECIPE_SCARECROW",
    category = "craft",
    ingredients = { wood = 5, moss = 2 },
    output = { item = "scarecrow", amount = 1 },
  },
  honey_cake = {
    name_key = "RECIPE_HONEY_CAKE",
    category = "bake",
    ingredients = { flour = 2, honey = 1, egg = 1 },
    output = { item = "honey_cake", amount = 1 },
  },
  pickaxe_copper = {
    name_key = "RECIPE_PICKAXE_COPPER",
    category = "craft",
    ingredients = { copper_ore = 3, wood = 2 },
    output = { item = "pickaxe_copper", amount = 1 },
  },
  lantern_post = {
    name_key = "RECIPE_LANTERN_POST",
    category = "craft",
    ingredients = { wood = 3, iron_ore = 2, glow_mushroom = 1 },
    output = { item = "lantern_post", amount = 1 },
  },
  fence = {
    name_key = "RECIPE_FENCE",
    category = "craft",
    ingredients = { wood = 4 },
    output = { item = "fence", amount = 4 },
  },
  iron_ingot = {
    name_key = "RECIPE_IRON_INGOT",
    category = "forge",
    ingredients = { iron_ore = 2 },
    output = { item = "iron_ingot", amount = 1 },
  },
  flower_necklace = {
    name_key = "RECIPE_FLOWER_NECKLACE",
    category = "craft",
    ingredients = { wild_flower = 5, moss = 1 },
    output = { item = "flower_necklace", amount = 1 },
  },
}
