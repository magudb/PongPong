kind = "config"
config = {
  farm_equipment = {
    sprinkler = { offsets = { {1,0}, {-1,0}, {0,1}, {0,-1} } },
    quality_sprinkler = { offsets = { {1,0}, {-1,0}, {0,1}, {0,-1}, {1,1}, {1,-1}, {-1,1}, {-1,-1} } },
    preserves_jar = { days = 2, output_prefix = "preserve_" },
    keg = { days = 3, output_prefix = "juice_" },
  },
  greenhouse = {
    name_key = "FARMSITE_GREENHOUSE",
    build_cost = { wood = 60, stone = 30, glass_pane = 8, gold = 1500 },
    build_days = 3,
    min_home_tier = 2,
    capacity = 12,
  },
}
