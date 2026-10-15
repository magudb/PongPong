-- lua/routines/core/baker_maja.lua - the daily routine of baker_maja (towns track; see docs: routine schema)
kind = "registry"
registry = "routines"

routines = {
    baker_maja = {
      home = "bageriet", home_area = "hyggebyen",
      work = "bageriet", work_area = "hyggebyen",
      priority = 5,
      shelter = "hyggebyen.door_bageriet",
      plans = {
        work = { blocks = {
          { from = 6, at = "hyggebyen.door_bageriet", act = "inside", leave = 6.5 },
          { at = "home.counter", act = "work", leave = 17 },
          { at = "hyggebyen.bakery_terrace", act = "sit", leave = 18 },
          { at = "hyggebyen.torv_fountain_e", act = "sit", leave = 20 },
          { at = "hyggebyen.door_bageriet", act = "inside" },
        } },
        mon = { blocks = {
          { from = 7, at = "hyggebyen.door_bageriet", act = "inside" },
          { from = 9, at = "hyggebyen.blossom_bench2", act = "sit" },
          { from = 11, at = "hyggebyen.torv_fountain_e", act = "sit" },
          { from = 14, at = "hyggebyen.well", act = "stand" },
          { from = 17, at = "hyggebyen.bakery_terrace", act = "sit" },
          { from = 20.5, at = "hyggebyen.door_bageriet", act = "inside" },
        } },
      },
      select = {
        { plan = "mon", when = { weekday = { 0 } } },
        { plan = "work" },
      },
    },
}
