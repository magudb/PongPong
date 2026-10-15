-- lua/routines/core/merchant_pip.lua - the daily routine of merchant_pip (towns track; see docs: routine schema)
kind = "registry"
registry = "routines"

routines = {
    merchant_pip = {
      home = "froebutikken", home_area = "hyggebyen",
      work = "froebutikken", work_area = "hyggebyen",
      priority = 5,
      shelter = "hyggebyen.door_froebutikken",
      plans = {
        work = { blocks = {
          { from = 6, at = "hyggebyen.door_froebutikken", act = "inside", leave = 7.5 },
          { at = "home.counter", act = "work", leave = 18 },
          { at = "hyggebyen.blossom_bench1", act = "sit", leave = 19 },
          { at = "hyggebyen.torv_fountain_n", act = "sit", leave = 20.5 },
          { at = "hyggebyen.door_froebutikken", act = "inside" },
        } },
        sun = { blocks = {
          { from = 8, at = "hyggebyen.door_froebutikken", act = "inside" },
          { from = 9.5, at = "hyggebyen.blossom_bench1", act = "sit" },
          { from = 12, at = "hyggebyen.well", act = "stand" },
          { from = 15, at = "hyggebyen.torv_fountain_n", act = "sit" },
          { from = 20.5, at = "hyggebyen.door_froebutikken", act = "inside" },
        } },
      },
      select = {
        { plan = "sun", when = { weekday = { 6 } } },
        { plan = "work" },
      },
    },
}
