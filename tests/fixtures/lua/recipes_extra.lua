-- tests/fixtures/lua/recipes_extra.lua
-- kind = "recipes" with the extra fields of the furniture recipes: station, min_home_tier, unlock_flag, nested ingredient
-- and output tables, a list of tags. LuaRuntime must hand all of it through untouched (data.kinds_shops_recipes_passthrough).

kind = "recipes"

recipes = {
  fixture_chair = {
    name_key = "RECIPE_FIXTURE_CHAIR",
    category = "craft",
    station = "snedkerbord",
    min_home_tier = 1,
    ingredients = { plank_pine = 3, nails = 3 },
    output = { item = "chair_pine", amount = 1 },
  },
  fixture_throne = {
    name_key = "RECIPE_FIXTURE_THRONE",
    category = "craft",
    station = "smedje",
    min_home_tier = 5,
    unlock_flag = "bp_kongelig",
    ingredients = { plank_oak = 8, gold_leaf = 2, velvet = 1 },
    output = { item = "throne_king", amount = 1 },
    tags = { "rare", "royal" },
  },
  fixture_cake = {
    name_key = "RECIPE_FIXTURE_CAKE",
    category = "bake",
    ingredients = { flour = 2, honey = 1, egg = 1 },
    output = { item = "honey_cake", amount = 1 },
  },
}
