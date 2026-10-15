-- lua/routines/core/fairy_tailor.lua - the daily routine of fairy_tailor (towns track; see docs: routine schema)
kind = "registry"
registry = "routines"

routines = {
    fairy_tailor = {
      home = "skraedderiet", home_area = "hyggebyen",
      work = "skraedderiet", work_area = "hyggebyen",
      priority = 4,
      shelter = "hyggebyen.door_skraedderiet",
      plans = {
        work = { blocks = {
          { from = 6.5, at = "hyggebyen.door_skraedderiet", act = "inside", leave = 8.5 },
          { at = "home.counter", act = "work", leave = 17 },
          { at = "hyggebyen.market_row2", act = "stand", leave = 18 },
          { at = "hyggebyen.torv_fountain_s", act = "sit", leave = 20.5 },
          { at = "hyggebyen.door_skraedderiet", act = "inside" },
        } },
        rest = { blocks = {
          { from = 9, at = "hyggebyen.door_skraedderiet", act = "inside" },
          { from = 11, at = "hyggebyen.market_row2", act = "stand" },
          { from = 14, at = "hyggebyen.blossom_bench2", act = "sit" },
          { from = 16.5, at = "hyggebyen.door_skraedderiet", act = "inside" },
        } },
      },
      select = {
        { plan = "rest", when = { weekday = { 0 } } },
        { plan = "work" },
      },
    },
}
