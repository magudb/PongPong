-- lua/routines/core/farmer_rosa.lua - the daily routine of farmer_rosa (towns track; see docs: routine schema)
kind = "registry"
registry = "routines"

routines = {
    farmer_rosa = {
      home = "dyrehuset", home_area = "hyggebyen",
      work = "dyrehuset", work_area = "hyggebyen",
      priority = 4,
      shelter = "hyggebyen.door_dyrehuset",
      plans = {
        work = { blocks = {
          { from = 6.5, at = "hyggebyen.door_dyrehuset", act = "inside", leave = 6.8333 },
          { at = "hyggebyen.rosa_pen", act = "tend", leave = 8.5 },
          { at = "home.counter", act = "work", leave = 17 },
          { at = "int_froebutikken.cust2", act = "stand", stay = 0.2 },
          { at = "hyggebyen.rosa_pen", act = "tend", leave = 18.6 },
          { at = "hyggebyen.torv_bench2", act = "sit", leave = 20.5 },
          { at = "hyggebyen.door_dyrehuset", act = "inside" },
        } },
        rest = { blocks = {
          { from = 8, at = "hyggebyen.door_dyrehuset", act = "inside" },
          { from = 8.5, at = "hyggebyen.rosa_pen", act = "tend" },
          { from = 11, at = "hyggebyen.market_row3", act = "stand" },
          { from = 14, at = "hyggebyen.torv_fountain_s", act = "sit" },
          { from = 17, at = "hyggebyen.rosa_pen", act = "tend" },
          { from = 21, at = "hyggebyen.door_dyrehuset", act = "inside" },
        } },
        work_sun = { blocks = {
          { from = 6.5, at = "hyggebyen.door_dyrehuset", act = "inside", leave = 6.8333 },
          { at = "hyggebyen.rosa_pen", act = "tend", leave = 8.5 },
          { at = "home.counter", act = "work", leave = 17 },
          { at = "hyggebyen.rosa_pen", act = "tend", leave = 18.6 },
          { at = "hyggebyen.torv_bench2", act = "sit", leave = 20.5 },
          { at = "hyggebyen.door_dyrehuset", act = "inside" },
        } },
      },
      select = {
        { plan = "rest", when = { weekday = { 3 } } },
        { plan = "work_sun", when = { weekday = { 6 } } },
        { plan = "work" },
      },
    },
}
