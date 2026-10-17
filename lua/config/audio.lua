kind = "config"
config = {
  audio_map = {
    fade = 1.5,
    areas = {
      farm = { day = "farm_day", night = "farm_night", music = "farm_theme", surface_default = "grass" },
      home = { day = "shop_interior", night = "shop_interior", music = "farm_theme", surface_default = "wood" },
      secret_garden = { day = "farm_day", night = "farm_night", music = "farm_theme", surface_default = "grass" },
      hyggebyen = { day = "town_day", night = "town_night", music = "city_theme", surface_default = "grass" },
      traetoppen = { day = "town_day", night = "town_night", music = "city_theme", surface_default = "wood" },
      moerkeskoven = { day = "forest", night = "forest_night", music = "forest_theme", surface_default = "dirt" },
      interior = { day = "shop_interior", night = "shop_interior", music = "city_theme", surface_default = "wood" },
    },
    surfaces = { d = "wood", c = "stone", ["="] = "rope", p = "dirt", ["."] = "grass", [","] = "grass", [";"] = "grass", f = "grass" },
    variants = { grass = 3, dirt = 3, wood = 3, stone = 3, rope = 2 },
    events = {
      gift_given = "gift_sparkle", post_read = "letter_rustle", bath_taken = "bath_splash",
      bin_payout = "bin_bell", relationship_changed = "stage_up",
      ladder_climbed = "door_open_wood", lift_ride = "door_open_wood", seeds_swapped = "gift_sparkle",
      landmark_entered = "pickup_soft", gem_set = "gem_set", weapon_equipped = "weapon_equip", appraisal_done = "appraisal_reveal",
    },
  },
}
