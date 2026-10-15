-- data/starter_kit.lua
-- What a new game starts with: the tools, the worn starter outfit and the first furniture (placed through the grid in this
-- order; the rest waits in the furniture store). `tools` is the kit EconomyManager.reset() hands over silently (id = amount);
-- the GDScript STARTER_KIT literal is a load-failure fallback only (tests assert the two are identical).
kind = "config"

config = {
  starter_kit = {
    tools = {
      hoe_wooden = 1,
      watering_can_copper = 1,
      axe_wooden = 1,
      pickaxe_wooden = 1,
      sword_rusty = 1,
      scythe = 1,
      turnip_seeds = 5,
      lantern_oil = 2,
      health_tonic = 1,
    },
    wardrobe = {
      worn = { "shirt_linen_cream", "pants_trousers_brown", "shoes_boots_brown" },
      owned = { "dress_sun_cream" },
    },
    furniture = {
      placed = { "bed_birch_single", "chest_pine" },
      stock = { table_round_pine = 1, chair_pine = 2, rug_runner_natural = 1, floor_lamp_iron = 1 },
    },
  },
}
