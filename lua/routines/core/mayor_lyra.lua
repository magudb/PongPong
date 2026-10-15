-- lua/routines/core/mayor_lyra.lua - the daily routine of mayor_lyra (towns track; see docs: routine schema)
kind = "registry"
registry = "routines"

routines = {
    mayor_lyra = {
      home = "hyldeblomsts_hus", home_area = "hyggebyen",
      work = "raadhuset", work_area = "traetoppen",
      priority = 4,
      shelter = "home.table",
      plans = {
        work = { blocks = {
          { from = 7, at = "home.table", act = "eat" },
          { from = 9.5, at = "work.mayor_desk", act = "work", leave = 15 },
          { at = "hyggebyen.torv_fountain_n", act = "sit", leave = 18.5 },
          { at = "home.table", act = "eat" },
          { from = 21.5, at = "home.bed", act = "sleep" },
        } },
        rest = { blocks = {
          { from = 8, at = "home.table", act = "eat" },
          { from = 10.5, at = "hyggebyen.blossom_bench1", act = "sit" },
          { from = 13, at = "hyggebyen.torv_fountain_n", act = "sit" },
          { from = 16, at = "hyggebyen.well", act = "stand" },
          { from = 18.5, at = "home.table", act = "eat" },
          { from = 21.5, at = "home.bed", act = "sleep" },
        } },
      },
      select = {
        { plan = "work", when = { weekday = { 1, 2, 3 } } },
        { plan = "rest" },
      },
    },
}
