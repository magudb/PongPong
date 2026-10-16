-- Static-area yields retain the original forage bonus. Generated floors use
-- dungeon_loot.node_yields exclusively, including its crystal aliases/fallback.
kind = "config"
config = {
  resource_nodes = {
    iron_ore = { art = "ore_iron", hp = 3, tool = "pickaxe", power = 1, item = "iron_ore", amount = { 1, 3 }, respawn_days = 3 },
    copper_ore = { art = "ore_copper", hp = 2, tool = "pickaxe", power = 1, item = "copper_ore", amount = { 1, 3 }, respawn_days = 3 },
    gold_ore = { art = "ore_gold", hp = 5, tool = "pickaxe", power = 3, item = "gold_ore", amount = { 1, 2 }, respawn_days = 3 },
    rock_stone = { art = "rock_grey", hp = 2, tool = "pickaxe", power = 1, item = "stone", amount = { 2, 4 }, respawn_days = 3 },
    tree_chop = { art = "tree_pine_forest", hp = 4, tool = "axe", power = 1, item = "wood", amount = { 2, 4 }, respawn_days = 3 },
    amethyst = { art = "crystal_amethyst", hp = 3, tool = "pickaxe", power = 2, item = "amethyst", amount = { 1, 2 }, respawn_days = 5 },
    emerald = { art = "crystal_emerald", hp = 4, tool = "pickaxe", power = 2, item = "emerald", amount = { 1, 1 }, respawn_days = 5 },
    moonstone = { art = "crystal_moonstone", hp = 5, tool = "pickaxe", power = 3, item = "moonstone", amount = { 1, 1 }, respawn_days = 5 },
    crystal_shard = { art = "crystal_amethyst", hp = 2, tool = "pickaxe", power = 1, item = "crystal_shard", amount = { 1, 2 }, respawn_days = 5 },
    glow_mushroom = { art = "glow_mushroom_cluster", hp = 1, forage = true, item = "glow_mushroom", amount = { 1, 2 }, rare_gem_chance = 0.08, respawn_days = 1 },
    rare_mushroom = { art = "glowmush_pink", hp = 1, forage = true, item = "rare_mushroom", amount = { 1, 2 }, rare_gem_chance = 0.08, respawn_days = 1 },
    night_bloom = { art = "crop_moonflower_3", hp = 1, forage = true, item = "night_bloom", amount = { 1, 1 }, rare_gem_chance = 0.08, respawn_days = 1 },
    moss_patch = { art = "floor_patch_a", hp = 1, forage = true, item = "moss", amount = { 1, 2 }, rare_gem_chance = 0.08, respawn_days = 1 },
    fern = { art = "bush_forest", hp = 1, forage = true, item = "fern", amount = { 1, 2 }, rare_gem_chance = 0.08, respawn_days = 1 },
    apple_tree = { art = "apple_tree", hp = 1, forage = true, item = "apple", amount = { 1, 3 }, respawn_days = 1 },
    planter_herb = { art = "planter_box", hp = 1, forage = true, item = "fern", amount = { 1, 2 }, respawn_days = 1 },
    planter_berry = { art = "planter_box_berry", hp = 1, forage = true, item = "strawberry", amount = { 1, 1 }, respawn_days = 1 },
  },
}
