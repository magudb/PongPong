-- social/gift_tastes.lua
-- What each citizen thinks of a gift.  ONE config key: gift_tastes = { universal, archetypes, npcs }.  Every list holds SELECTORS:
--   "<item id>"        one item (the most specific rule)
--   "ftype:<t>"        furniture_type   (lamp plant rug table chair shelf sofa bed hearth instrument decor wall_decor storage grand)
--   "slot:<s>"         clothing slot    (hat shirt pants dress shoes jewellery)
--   "set:<id>"         furniture/wardrobe set
--   "category:<c>"     item category    (crop forage food product gem mineral magic tool weapon resource ...)
--   "rarity:<r>"       normal | uncommon | rare   (unique and legendary keepsakes can never be given)
-- Resolution order for one (npc, item): the NPC's own row, then the archetype row, then `universal`; inside one row an item id beats
-- ftype/slot/set, which beats category, which beats rarity; classes are love > like > neutral (everything else) > dislike > hate.
-- The same selector may not stand in two classes of one row (validator rule).  Loved things are worth 40 points, liked 20, neutral 8,
-- disliked and hated 0 (never negative: the world stays cozy); see lua/social/social.lua.
kind = "config"

config = {
  gift_tastes = {
    universal = {
      like = { "honey_cake", "cookie", "apple", "strawberry" },
      dislike = { "category:resource", "fertilizer", "category:animal_care" },
      hate = { "category:weapon" },
    },
    archetypes = {
      gardener = {
        love = { "carrot", "sunflower", "category:crop" },
        like = { "wild_flower", "fairy_dust_water", "ftype:plant", "category:seed" },
        dislike = { "category:mineral" },
        hate = { "lantern_oil" },
      },
      craftsman = {
        love = { "plank_oak", "timber_beam", "honey" },
        like = { "category:building_material", "category:tool", "nails", "category:mineral" },
        dislike = { "wild_flower", "category:crop" },
        hate = { "magic_scroll" },
      },
      fairy = {
        love = { "wild_flower", "circlet_daisy", "honey" },
        like = { "category:forage", "slot:jewellery", "ftype:wall_decor", "ftype:lamp" },
        dislike = { "category:mineral", "iron_ingot" },
        hate = { "egg" },
      },
      shopkeeper = {
        love = { "honey_cake", "strawberry", "moonflower" },
        like = { "flour", "milk", "egg", "category:crop", "category:food" },
        dislike = { "stone", "wood" },
        hate = { "iron_ore" },
      },
      elder = {
        love = { "honey", "ftype:decor", "milk" },
        like = { "category:gem", "ftype:shelf", "ftype:chair", "slot:hat" },
        dislike = { "category:crop", "stone" },
        hate = { "lantern_oil" },
      },
      child = {
        love = { "cookie", "honey_cake", "wild_flower", "strawberry" },
        like = { "category:food", "slot:jewellery", "category:crop" },
        dislike = { "category:consumable", "category:tool" },
        hate = { "iron_ore" },
      },
      watcher = {
        love = { "glow_mushroom", "night_bloom", "lantern_oil" },
        like = { "category:forage", "slot:shoes", "rope" },
        dislike = { "sunflower", "category:crop" },
        hate = { "fairy_dust" },
      },
      wanderer = {
        love = { "apple", "cookie", "slot:shoes" },
        like = { "category:forage", "category:food", "slot:hat", "rope" },
        dislike = { "category:mineral", "ftype:grand" },
        hate = { "iron_sword" },
      },
    },
    npcs = {
      mayor_lyra = { archetype = "fairy", love = { "dress_gown_rose", "circlet_tiara_silver", "honey_cake" }, like = { "ftype:wall_decor", "category:magic" }, dislike = { "egg", "milk" } },
      baker_maja = { archetype = "shopkeeper", love = { "flour", "honey", "strawberry", "hat_chef_white" }, like = { "egg", "duck_egg", "milk", "apple" }, dislike = { "stone" }, hate = { "iron_ore", "fertilizer" } },
      merchant_pip = { archetype = "shopkeeper", love = { "moonflower", "glow_berry", "sunflower" }, like = { "category:seed", "wild_flower" }, dislike = { "wood" }, hate = { "iron_ore" } },
      gardener_hoppe = { archetype = "gardener", love = { "carrot", "moonflower", "plant_fern", "fairy_dust_water" }, like = { "turnip", "strawberry", "category:crop", "ftype:plant" }, dislike = { "stone", "wood" }, hate = { "iron_sword", "lantern_oil" } },
      carpenter_brumme = { archetype = "craftsman", love = { "honey", "timber_beam", "plank_oak", "chair_oak" }, like = { "ftype:table", "axe_wooden", "rope", "nails" }, dislike = { "wild_flower" }, hate = { "magic_scroll", "fabric_velvet" } },
      postman_pip = { archetype = "wanderer", love = { "apple", "shoes_wellies_yellow", "hat_cap_blue", "cookie" }, like = { "slot:shoes", "ftype:chair", "category:food" }, dislike = { "ftype:grand" }, hate = { "iron_sword" } },
      bathkeeper_sofus = { archetype = "elder", love = { "honey_cake", "shoes_slippers_cream", "rug_natural", "honey" }, like = { "ftype:rug", "ftype:hearth", "curtain_natural", "apple" }, dislike = { "category:mineral" }, hate = { "lantern_oil", "iron_ore" } },
      beekeeper_birk = { archetype = "gardener", love = { "honey", "honey_cake", "sunflower", "circlet_daisy" }, like = { "wild_flower", "plant_fern", "ftype:plant" }, dislike = { "fertilizer" }, hate = { "pickaxe_wooden", "egg" } },
      smith_thorin = { archetype = "craftsman", love = { "iron_ingot", "iron_ore", "copper_ore", "gold_ore" }, like = { "category:tool", "category:mineral", "honey" }, dislike = { "wild_flower", "category:crop" }, hate = { "magic_scroll", "fairy_dust" } },
      farmer_rosa = { archetype = "gardener", love = { "egg", "milk", "wool", "animal_treats" }, like = { "category:product", "chicken_feed", "carrot" }, dislike = { "category:mineral" }, hate = { "iron_sword" } },
      pippin_boegeknop = { archetype = "wanderer", love = { "cookie", "hat_cap_brown", "chair_oak" }, like = { "ftype:chair", "category:food", "rope" }, dislike = { "ftype:grand" }, hate = { "magic_scroll" } },
      fairy_lily = { archetype = "child", love = { "cookie", "honey_cake", "circlet_daisy", "wild_flower" }, like = { "strawberry", "necklace_leaf", "bracelet_string" }, dislike = { "health_tonic" }, hate = { "iron_ore", "stone" } },
      guard_oak = { archetype = "watcher", love = { "honey", "apple", "lantern_oil", "rope" }, like = { "slot:shoes", "iron_ingot" }, dislike = { "wild_flower" }, hate = { "fairy_dust", "magic_scroll" } },
      fairy_wizard = { archetype = "elder", love = { "magic_scroll", "mana_potion", "fairy_dust", "amethyst" }, like = { "category:magic", "set:troldmanden", "ftype:shelf" }, dislike = { "category:crop" }, hate = { "fertilizer", "egg" } },
      fairy_builder = { archetype = "craftsman", love = { "plank_oak", "plank_pine", "nails", "glass_pane" }, like = { "category:building_material", "honey" }, dislike = { "wild_flower" }, hate = { "magic_scroll" } },
      fairy_furnisher = { archetype = "fairy", love = { "ftype:lamp", "ftype:plant", "rug_round_rose" }, like = { "ftype:wall_decor", "ftype:rug", "curtain_blue" }, dislike = { "stone" }, hate = { "egg" } },
      fairy_tailor = { archetype = "fairy", love = { "fabric_velvet", "fabric_wool", "slot:dress" }, like = { "fabric_plain", "slot:shirt", "wool" }, dislike = { "stone" }, hate = { "fertilizer" } },
      appraiser_fru_ugle = { archetype = "elder", love = { "amethyst", "moonstone", "amber", "wisdom_feather" }, like = { "category:gem", "rose_quartz", "crystal_shard", "ftype:shelf" }, dislike = { "category:crop" }, hate = { "lantern_oil", "rope" } },
      mapseller_natteblik = { archetype = "watcher", love = { "night_bloom", "glow_mushroom", "glow_berry", "lantern_oil" }, like = { "rare_mushroom", "moss", "category:forage" }, dislike = { "slot:hat", "category:crop" }, hate = { "fairy_dust", "sunflower" } },
      fairy_king = { archetype = "elder", love = { "moonstone", "emerald", "honey_cake" }, like = { "category:gem", "ftype:decor", "set:kongelig" }, dislike = { "category:resource" }, hate = { "egg" } },
      rasmus = { archetype = "wanderer", love = { "wild_flower", "rare_mushroom", "moss", "fern" }, like = { "apple", "category:forage", "rope" }, dislike = { "ftype:grand" }, hate = { "iron_sword" } },
      lamplighter_kiki = { archetype = "wanderer", love = { "apple", "strawberry", "sunflower", "rope" }, like = { "lucky_clover", "category:forage" }, dislike = { "category:mineral" }, hate = { "iron_sword" } },
      bertil = { archetype = "gardener", love = { "honey_cake", "cookie", "apple", "shirt_vest_green" }, like = { "carrot", "turnip", "pants_dungarees_brown" }, dislike = { "category:mineral" }, hate = { "fairy_dust" } },
      bodil = { archetype = "gardener", love = { "circlet_daisy", "wild_flower", "strawberry", "dress_pinafore_blue" }, like = { "honey", "cookie", "ftype:plant" }, dislike = { "category:mineral" }, hate = { "iron_ore" } },
      cat_morfar_mis = { archetype = "elder", love = { "milk", "egg", "wool" }, like = { "duck_egg", "honey" }, dislike = { "category:crop" }, hate = { "lantern_oil" } },
      innkeeper_kvak = { archetype = "shopkeeper", love = { "honey_cake", "apple", "milk", "cookie" }, like = { "category:food", "ftype:table", "ftype:chair" }, dislike = { "category:mineral" }, hate = { "lantern_oil" } },
      cub_bamse = { archetype = "child", love = { "honey", "honey_cake", "cookie" }, like = { "strawberry", "apple", "slot:hat" }, dislike = { "category:tool" }, hate = { "iron_ore" } },
      clerk_fjerpen = { archetype = "watcher", love = { "milk", "ftype:shelf", "wisdom_feather" }, like = { "bookshelf_pine", "category:forage" }, dislike = { "category:crop" }, hate = { "egg" } },
      fiddler_strimmel = { archetype = "wanderer", love = { "apple", "ftype:instrument", "honey" }, like = { "category:forage", "slot:hat" }, dislike = { "category:weapon" }, hate = { "iron_ore" } },
      penguin_postman = { archetype = "wanderer", love = { "shoes_wellies_blue", "cookie", "milk" }, like = { "slot:shoes", "apple" }, dislike = { "ftype:hearth" }, hate = { "iron_sword" } },
          ghostfam_dyne = { archetype = "elder", love = { "wool", "fabric_wool", "honey_cake", "shirt_knit_cream" }, like = { "honey", "milk", "ftype:rug", "curtain_natural", "lantern_oil", "slot:hat" }, dislike = { "category:crop" } },
      ghostfam_gnist = { archetype = "shopkeeper", love = { "glow_mushroom", "night_bloom", "glow_berry", "floor_lamp_birch" }, like = { "lantern_oil", "ftype:lamp", "moss", "category:forage" }, dislike = { "sunflower" } },
      ghostfam_silke = { archetype = "watcher", love = { "lantern_oil", "glow_mushroom", "honey", "moonflower" }, like = { "slot:shoes", "apple", "ftype:lamp", "rope" }, dislike = { "sunflower" } },
      ghostfam_blund = { archetype = "child", love = { "cookie", "glow_mushroom", "honey_cake", "bracelet_string" }, like = { "wild_flower", "apple", "slot:hat", "night_bloom" }, dislike = { "health_tonic" } },
},
  },
}
