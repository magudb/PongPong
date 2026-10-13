-- config/rarity.lua
-- Five rarity ranks (normal, uncommon, rare, unique, legendary) shared by furniture, clothing and materials, and the perk caps.
-- Review fixes: legendary = the night tile (CD1; icons get a pale _night rim variant because ink on 2f3654 is 1.25:1), unique label 7d2e59 (CIEDE2000 13.0 from Tornebaer b3436b, the damage colour;
-- the content value a8456a was 2.2), uncommon label 3f6b22 (4.5:1).
-- UI colours are hex WITHOUT the leading # (P10 lint reads # as an unsupported Lua token).  The gold ring is reserved for focus/selected.

kind = "config"

config = {
  rarity_tiers = {
    order = { "normal", "uncommon", "rare", "unique", "legendary" },
    normal = {
      rank = 1,
      name_key = "RARITY_NORMAL",
      ui = { fill = "fbf5e6", ring = "2b2340", label = "4c4058" },
      furniture_price = 150,
      clothing_price = 60,
      sell_ratio = 0.4,
      decor = 2,
      find_weight = 100,
    },
    uncommon = {
      rank = 2,
      name_key = "RARITY_UNCOMMON",
      ui = { fill = "e3efd2", ring = "6b9a3e", label = "3f6b22" },
      furniture_price = 450,
      clothing_price = 220,
      sell_ratio = 0.4,
      decor = 5,
      find_weight = 40,
    },
    rare = {
      rank = 3,
      name_key = "RARITY_RARE",
      ui = { fill = "e2d8f4", ring = "9b86d6", label = "5d4fa3" },
      furniture_price = 1600,
      clothing_price = 800,
      sell_ratio = 0.38,
      decor = 11,
      find_weight = 12,
    },
    unique = {
      rank = 4,
      name_key = "RARITY_UNIQUE",
      ui = { fill = "f9e0e7", ring = "e58fa6", label = "7d2e59" },
      furniture_price = 5000,
      clothing_price = 2600,
      sell_ratio = 0.0,
      decor = 24,
      find_weight = 3,
    },
    legendary = {
      rank = 5,
      name_key = "RARITY_LEGENDARY",
      ui = { fill = "2f3654", ring = "a9d3e0", label = "2b2340", pip = "f2c14e", icon_rim = "e4eff5" },
      furniture_price = 12000,
      clothing_price = 7000,
      sell_ratio = 0.0,
      decor = 42,
      find_weight = 1,
    },
  },
  perk_caps = { speed = 0.15, energy = 20, luck = 0.2, discount = 0.15, energy_total = 60, discount_total = 0.2 },
}
