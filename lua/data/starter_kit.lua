-- data/starter_kit.lua
-- What a new game starts with: the worn starter outfit and the first furniture (placed through the grid in this order; the rest waits in the furniture store).
kind = "config"

config = {
  starter_kit = {
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
