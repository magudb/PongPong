-- items/magic.lua
-- Magic goods of the wizard's shop and of the forest (P12).  fairy_dust lives ONLY here (the duplicate in resources.lua is gone).
-- glow_berry and its seeds are the 8th crop of game_balance.lua (sold by the magic store; crop art is a placeholder until P22).
--
-- CUT in the 2D rewrite (no mechanic, no quest or dialogue names them): teleport_stone and enchanted_soil.  mana_potion is
-- kept as the energy tonic: it restores `stamina` (the Energi bar), nothing else is promised.
-- magic_scroll is a curio and a quest reward (math_wizard_quiz): it can be sold and does nothing else.

kind = "items"

items = {
  fairy_dust = {
    name_key = "ITEM_FAIRY_DUST",
    description_key = "ITEM_FAIRY_DUST_DESC",
    category = "magic",
    rarity = "rare",
    max_stack = 99,
    buy_price = 300,
    sell_price = 150,
  },
  crystal_shard = {
    name_key = "ITEM_CRYSTAL_SHARD",
    description_key = "ITEM_CRYSTAL_SHARD_DESC",
    category = "gem",
    rarity = "uncommon",
    max_stack = 99,
    buy_price = 120,
    sell_price = 55,
  },
  magic_scroll = {
    name_key = "ITEM_MAGIC_SCROLL",
    description_key = "ITEM_MAGIC_SCROLL_DESC",
    category = "magic",
    rarity = "uncommon",
    max_stack = 20,
    buy_price = 250,
    sell_price = 100,
  },
  mana_potion = {
    name_key = "ITEM_MANA_POTION",
    description_key = "ITEM_MANA_POTION_DESC",
    category = "consumable",
    stamina = 40,
    stamina_cost = 0,
    rarity = "normal",
    max_stack = 20,
    buy_price = 90,
    sell_price = 35,
  },
  glow_berry_seeds = {
    name_key = "ITEM_GLOW_BERRY_SEEDS",
    description_key = "ITEM_GLOW_BERRY_SEEDS_DESC",
    category = "seed",
    crop_id = "glow_berry",
    stamina_cost = 0.5,
    rarity = "uncommon",
    max_stack = 99,
    buy_price = 95,
    sell_price = 30,
  },
  glow_berry = {
    name_key = "ITEM_GLOW_BERRY",
    description_key = "ITEM_GLOW_BERRY_DESC",
    category = "crop",
    rarity = "uncommon",
    max_stack = 99,
    buy_price = 0,
    sell_price = 150,
  },
}
