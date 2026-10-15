-- lua/routines/core/fairy_furnisher.lua - the daily routine of fairy_furnisher (towns track; see docs: routine schema)
kind = "registry"
registry = "routines"

routines = {
    fairy_furnisher = {
      home = "moebelbutikken", home_area = "hyggebyen",
      work = "moebelbutikken", work_area = "hyggebyen",
      priority = 4,
      shelter = "hyggebyen.door_moebelbutikken",
      plans = {
        work = { blocks = {
          { from = 6.5, at = "hyggebyen.door_moebelbutikken", act = "inside", leave = 8.5 },
          { at = "home.counter", act = "work", leave = 17 },
          { at = "hyggebyen.market_row1", act = "stand", leave = 18 },
          { at = "hyggebyen.torv_fountain_w", act = "sit", leave = 20.5 },
          { at = "hyggebyen.door_moebelbutikken", act = "inside" },
        } },
        rest = { blocks = {
          { from = 9, at = "hyggebyen.door_moebelbutikken", act = "inside" },
          { from = 11, at = "hyggebyen.market_row1", act = "stand" },
          { from = 14, at = "hyggebyen.blossom_bench1", act = "sit" },
          { from = 17, at = "hyggebyen.torv_fountain_w", act = "sit" },
          { from = 21, at = "hyggebyen.door_moebelbutikken", act = "inside" },
        } },
      },
      select = {
        { plan = "rest", when = { weekday = { 2 } } },
        { plan = "work" },
      },
    },
}
