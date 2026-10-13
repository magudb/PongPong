-- data/sets.lua
-- Themed sets.  furniture_sets: bonus while enough pieces are PLACED in the home; wardrobe_sets: bonus while enough pieces are WORN.
-- bonuses[]: the highest entry whose `pieces` is reached applies (not cumulative).  capstone: legendary reward for owning every other member.
-- wardrobe_sets: every `pieces` is <= the number of members that can be worn AT ONCE (one per equip slot; dress excludes shirt + pants, hat excludes circlet; at most 7, with a dress 6) - validator R15.

kind = "config"

config = {
  furniture_sets = {
    bondegaard = {
      name_key = "FSET_BONDEGAARD",
      description_key = "FSET_BONDEGAARD_DESC",
      members = { "bed_pine", "bookshelf_pine", "chair_pine", "chest_pine", "clock_pine", "curtain_natural", "fireplace_granite", "floor_lamp_iron", "plant_fern", "rug_natural", "sofa_pine_two", "table_dining_oak", "vase_clay", "wardrobe_pine" },
      bonuses = {
        { pieces = 3, energy = 2 },
        { pieces = 6, energy = 4, discount = 0.01 },
        { pieces = 10, energy = 6, discount = 0.02 },
      },
    },
    fe_bo = {
      name_key = "FSET_FE_BO",
      description_key = "FSET_FE_BO_DESC",
      members = { "bed_rose_single", "bookshelf_lavender_narrow", "chair_lavender", "chest_rose", "curtain_blue", "painting_rose_wide", "piano_sky", "plant_rose_pot", "rug_round_rose", "table_lamp_sky", "vase_rose", "wardrobe_rose" },
      bonuses = {
        { pieces = 3, luck = 0.01 },
        { pieces = 6, luck = 0.02, energy = 2 },
        { pieces = 9, luck = 0.03, energy = 3 },
      },
    },
    solstuen = {
      name_key = "FSET_SOLSTUEN",
      description_key = "FSET_SOLSTUEN_DESC",
      members = { "bed_cherry", "chair_honey", "curtain_red", "fireplace_chalk", "floor_lamp_honey", "plant_flowering", "rug_striped_blue", "table_round_cherry", "throne_honey" },
      bonuses = {
        { pieces = 3, energy = 2 },
        { pieces = 5, energy = 3, luck = 0.01 },
        { pieces = 7, energy = 4, luck = 0.02 },
      },
    },
    kongelig = {
      name_key = "FSET_KONGELIG",
      description_key = "FSET_KONGELIG_DESC",
      members = { "bed_walnut", "candelabra_brass", "chandelier_gold", "fireplace_marble", "floor_lamp_brass", "painting_gold_wide", "piano_walnut", "rug_burgundy", "rug_gold_round", "sofa_cherry_three", "sofa_walnut_two", "table_long_walnut", "throne_king", "wardrobe_walnut" },
      bonuses = {
        { pieces = 3, discount = 0.01 },
        { pieces = 6, discount = 0.02, luck = 0.01 },
        { pieces = 10, discount = 0.03, luck = 0.02 },
        { pieces = 14, discount = 0.04, luck = 0.02 },
      },
    },
    svampehytten = {
      name_key = "FSET_SVAMPEHYTTEN",
      description_key = "FSET_SVAMPEHYTTEN_DESC",
      members = { "bed_toadstool", "floor_lamp_glowshroom", "piano_toadstool", "rug_round_red", "table_stump" },
      bonuses = {
        { pieces = 2, luck = 0.01 },
        { pieces = 3, luck = 0.02, energy = 2 },
        { pieces = 5, luck = 0.03, energy = 4 },
      },
    },
    hobbithulen = {
      name_key = "FSET_HOBBITHULEN",
      description_key = "FSET_HOBBITHULEN_DESC",
      members = { "bed_oak_single", "bookshelf_book_tree", "chair_mossy", "chair_stump", "curtain_green", "rug_runner_green", "sofa_leaf", "sofa_moss_three", "throne_root", "wardrobe_hollow_log" },
      bonuses = {
        { pieces = 3, energy = 2 },
        { pieces = 6, energy = 4 },
        { pieces = 8, energy = 6 },
      },
    },
    skovens_hjerte = {
      name_key = "FSET_SKOVENS_HJERTE",
      description_key = "FSET_SKOVENS_HJERTE_DESC",
      members = { "chest_snail", "clock_owl", "fireplace_cauldron", "painting_porthole", "plant_teapot_bonsai", "rug_flower_petal", "shelf_birdhouse" },
      bonuses = {
        { pieces = 2, luck = 0.01 },
        { pieces = 4, luck = 0.02, energy = 2 },
        { pieces = 7, luck = 0.04, energy = 4 },
      },
    },
    maanelys = {
      name_key = "FSET_MAANELYS",
      description_key = "FSET_MAANELYS_DESC",
      members = { "bed_moon", "chandelier_star", "clock_moon", "fireplace_moon", "floor_lamp_fairy", "piano_star", "rug_magic_circle", "sofa_cloud" },
      bonuses = {
        { pieces = 2, energy = 3 },
        { pieces = 4, energy = 5, luck = 0.02 },
        { pieces = 6, energy = 7, luck = 0.03 },
        { pieces = 8, energy = 9, luck = 0.04 },
      },
    },
    troldmandens_taarn = {
      name_key = "FSET_TROLDMANDENS_TAARN",
      description_key = "FSET_TROLDMANDENS_TAARN_DESC",
      members = { "bookshelf_ebony", "bookshelf_floating", "chair_ebony", "clock_walnut", "table_lamp_brass" },
      bonuses = {
        { pieces = 2, luck = 0.01 },
        { pieces = 3, luck = 0.02, energy = 2 },
        { pieces = 5, luck = 0.03, energy = 4 },
      },
    },
    krystalgrotten = {
      name_key = "FSET_KRYSTALGROTTEN",
      description_key = "FSET_KRYSTALGROTTEN_DESC",
      members = { "chandelier_lantern_flower", "chest_rune", "fireplace_slate", "throne_crystal" },
      bonuses = {
        { pieces = 2, energy = 2 },
        { pieces = 3, energy = 4, luck = 0.01 },
        { pieces = 4, energy = 6, luck = 0.02 },
      },
    },
  },
  wardrobe_sets = {
    marken = {
      name_key = "OUTFIT_MARKEN",
      description_key = "OUTFIT_MARKEN_DESC",
      members = { "hat_straw_green", "hat_straw_harvest", "hat_straw_plain", "pants_dungarees_brown", "pants_trousers_brown", "shirt_knit_dawn", "shirt_linen_cream", "shirt_smock_brown", "shoes_boots_brown", "shoes_clogs_wood" },
      bonuses = {
        { pieces = 3, energy = 2 },
        { pieces = 4, energy = 5, speed = 0.01 },
      },
      capstone = "shirt_knit_dawn",
    },
    skovstrejfer = {
      name_key = "OUTFIT_SKOVSTREJFER",
      description_key = "OUTFIT_SKOVSTREJFER_DESC",
      members = { "hat_acorn_gold", "hat_acorn_plain", "hat_hood_green", "necklace_acorn", "pants_breeches_tweed", "pants_trousers_green", "shirt_vest_green", "shoes_boots_green" },
      bonuses = {
        { pieces = 3, speed = 0.01 },
        { pieces = 4, energy = 2, speed = 0.02 },
        { pieces = 5, energy = 3, speed = 0.03 },
      },
    },
    fe_festen = {
      name_key = "OUTFIT_FE_FESTEN",
      description_key = "OUTFIT_FE_FESTEN_DESC",
      members = { "circlet_tiara_silver", "dress_gown_aurora", "dress_gown_lavender", "dress_gown_rose", "hat_straw_ribbon", "necklace_moonstone", "shirt_knit_lavender", "shoes_slippers_lavender", "shoes_slippers_silk" },
      bonuses = {
        { pieces = 3, luck = 0.01 },
        { pieces = 4, discount = 0.02, luck = 0.03 },
      },
      capstone = "dress_gown_aurora",
    },
    bageren = {
      name_key = "OUTFIT_BAGEREN",
      description_key = "OUTFIT_BAGEREN_DESC",
      members = { "bracelet_string", "dress_pinafore_baker", "dress_pinafore_blue", "dress_pinafore_brown", "dress_pinafore_honey", "hat_chef_white" },
      bonuses = {
        { pieces = 2, discount = 0.01 },
        { pieces = 3, discount = 0.03, energy = 2 },
      },
    },
    troldmanden = {
      name_key = "OUTFIT_TROLDMANDEN",
      description_key = "OUTFIT_TROLDMANDEN_DESC",
      members = { "bracelet_silver", "hat_wizard_lavender", "hat_wizard_night", "hat_wizard_zephyr", "necklace_moonstone_small", "pants_trousers_stripe", "shirt_knit_blue" },
      bonuses = {
        { pieces = 3, luck = 0.01 },
        { pieces = 4, energy = 2, luck = 0.02 },
        { pieces = 5, energy = 3, luck = 0.03 },
      },
      capstone = "hat_wizard_night",
    },
    svampesamleren = {
      name_key = "OUTFIT_SVAMPESAMLEREN",
      description_key = "OUTFIT_SVAMPESAMLEREN_DESC",
      members = { "earrings_glowcap", "hat_mushroom_glow", "hat_mushroom_red", "hat_mushroom_spinner", "shoes_slippers_pompom" },
      bonuses = {
        { pieces = 2, luck = 0.01 },
        { pieces = 3, energy = 2, luck = 0.03 },
      },
    },
    nattevandreren = {
      name_key = "OUTFIT_NATTEVANDREREN",
      description_key = "OUTFIT_NATTEVANDREREN_DESC",
      members = { "bracelet_vine", "necklace_dewdrop", "pants_trousers_moss", "pants_trousers_starlight", "shirt_knit_thornberry", "shirt_linen_firefly", "shoes_boots_dark", "shoes_boots_star" },
      bonuses = {
        { pieces = 3, luck = 0.01, speed = 0.01 },
        { pieces = 4, luck = 0.02, speed = 0.02 },
        { pieces = 5, energy = 2, luck = 0.02, speed = 0.03 },
      },
      capstone = "pants_trousers_starlight",
    },
  },
}
