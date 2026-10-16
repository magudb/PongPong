-- data/wardrobe_rules.lua
-- How clothing items map to the nine equipment slots of the wardrobe art (z = draw order above the body) and which slots exclude each other.
-- Equipping an item into a slot unequips every slot it is exclusive with.  max_sets_counted: at most this many outfit sets give a bonus at the same time (the two best).

kind = "config"

config = {
  wardrobe = {
    equip_slots = {
      pants = { item_slot = "pants", z = 10, name_key = "WARDROBE_SLOT_PANTS" },
      shoes = { item_slot = "shoes", z = 12, name_key = "WARDROBE_SLOT_SHOES" },
      shirt = { item_slot = "shirt", z = 20, name_key = "WARDROBE_SLOT_SHIRT" },
      dress = { item_slot = "dress", z = 21, name_key = "WARDROBE_SLOT_DRESS" },
      bracelet = { item_slot = "jewellery", subslot = "bracelet", z = 25, name_key = "WARDROBE_SUBSLOT_BRACELET" },
      necklace = { item_slot = "jewellery", subslot = "necklace", z = 30, name_key = "WARDROBE_SUBSLOT_NECKLACE" },
      earrings = { item_slot = "jewellery", subslot = "earrings", z = 35, name_key = "WARDROBE_SUBSLOT_EARRINGS" },
      hat = { item_slot = "hat", z = 40, name_key = "WARDROBE_SLOT_HAT" },
      circlet = { item_slot = "jewellery", subslot = "circlet", z = 41, name_key = "WARDROBE_SUBSLOT_CIRCLET" },
    },
    exclusive = {
      { "dress", "shirt" },
      { "dress", "pants" },
      { "hat", "circlet" },
    },
    max_sets_counted = 2,
    layer_z = { pants_dungarees = 22 }, -- bib and straps sit over the shirt
  },
}
