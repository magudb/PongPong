-- lua/routines/core/penguin_postman.lua - the daily routine of penguin_postman (towns track; see docs: routine schema)
kind = "registry"
registry = "routines"

routines = {
    penguin_postman = {
      home = "pingvinens_hus", home_area = "hyggebyen",
      priority = 2,
      shelter = "hyggebyen.door_pingvinens_hus",
      plans = {
        work = { blocks = {
          { from = 7, at = "hyggebyen.door_pingvinens_hus", act = "inside", leave = 7.5 },
          { at = "traetoppen.door_postkontoret", act = "stand", stay = 0.1667 },
          { at = "hyggebyen.round_e", act = "patrol", stay = 0.0833 },
          { at = "hyggebyen.door_froebutikken", act = "stand", stay = 0.1333 },
          { at = "hyggebyen.door_bageriet", act = "stand", stay = 0.1333 },
          { at = "hyggebyen.round_s", act = "patrol", stay = 0.0833 },
          { at = "hyggebyen.door_dyrehuset", act = "stand", stay = 0.1333 },
          { at = "hyggebyen.round_w", act = "patrol", stay = 0.0833 },
          { at = "hyggebyen.door_pippins_hus", act = "stand", stay = 0.1333 },
          { at = "hyggebyen.door_pingvinens_hus", act = "inside" },
        } },
        rest = { blocks = {
          { from = 9, at = "hyggebyen.door_pingvinens_hus", act = "inside" },
          { from = 10.5, at = "hyggebyen.torv_bench1", act = "sit" },
          { from = 13.5, at = "hyggebyen.pond_dock", act = "fish" },
          { from = 15.25, at = "hyggebyen.door_pingvinens_hus", act = "inside" },
        } },
      },
      select = {
        { plan = "rest", when = { weekday = { 6 } } },
        { plan = "work" },
      },
    },
}
