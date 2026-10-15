-- lua/routines/core/smith_thorin.lua - the daily routine of smith_thorin (towns track; see docs: routine schema)
kind = "registry"
registry = "routines"

routines = {
    smith_thorin = {
      home = "smedjen", home_area = "hyggebyen",
      work = "smedjen", work_area = "hyggebyen",
      priority = 4,
      shelter = "hyggebyen.door_smedjen",
      plans = {
        work = { blocks = {
          { from = 6.5, at = "hyggebyen.door_smedjen", act = "inside", leave = 7.5833 },
          { at = "int_bageriet.cust1", act = "stand", stay = 0.1667 },
          { at = "home.counter", act = "work", leave = 17 },
          { at = "hyggebyen.forge_front", act = "work", leave = 18.5 },
          { at = "hyggebyen.torv_fountain_e", act = "sit", leave = 21 },
          { at = "hyggebyen.door_smedjen", act = "inside" },
        } },
        sun = { blocks = {
          { from = 8.5, at = "hyggebyen.door_smedjen", act = "inside" },
          { from = 10, at = "hyggebyen.forge_front", act = "work" },
          { from = 13, at = "hyggebyen.torv_bench2", act = "sit" },
          { from = 17, at = "hyggebyen.torv_fountain_e", act = "sit" },
          { from = 21.5, at = "hyggebyen.door_smedjen", act = "inside" },
        } },
        inn = { blocks = {
          { from = 6.5, at = "hyggebyen.door_smedjen", act = "inside", leave = 7.5833 },
          { at = "int_bageriet.cust1", act = "stand", stay = 0.1667 },
          { at = "home.counter", act = "work", leave = 17 },
          { at = "hyggebyen.forge_front", act = "work", leave = 18 },
          { from = 19.5, at = "int_torvekroen.seat_f?", act = "sit" },
          { from = 23, at = "hyggebyen.door_smedjen", act = "inside" },
        } },
        work_mon = { blocks = {
          { from = 6.5, at = "hyggebyen.door_smedjen", act = "inside", leave = 8.5 },
          { at = "home.counter", act = "work", leave = 17 },
          { at = "hyggebyen.forge_front", act = "work", leave = 18.5 },
          { at = "hyggebyen.torv_fountain_e", act = "sit", leave = 21 },
          { at = "hyggebyen.door_smedjen", act = "inside" },
        } },
      },
      select = {
        { plan = "sun", when = { weekday = { 6 } } },
        { plan = "work_mon", when = { weekday = { 0 } } },
        { plan = "inn", when = { weekday = { 4 } } },
        { plan = "work" },
      },
    },
}
