-- lua/routines/core/pippin_boegeknop.lua - the daily routine of pippin_boegeknop (towns track; see docs: routine schema)
kind = "registry"
registry = "routines"

routines = {
    pippin_boegeknop = {
      home = "pippins_hus", home_area = "hyggebyen",
      work = "loppeloftet", work_area = "hyggebyen",
      priority = 4,
      shelter = "home.table",
      plans = {
        work = { blocks = {
          { from = 7.5, at = "home.table", act = "eat" },
          { from = 9.5, at = "hyggebyen.pond_dock", act = "fish" },
          { from = 12.5, at = "home.table", act = "eat" },
          { from = 14, at = "hyggebyen.torv_bench1", act = "sit" },
          { from = 17.5, at = "home.table", act = "eat" },
          { from = 21.5, at = "home.bed", act = "sleep" },
        } },
        weekend = { blocks = {
          { from = 8, at = "home.table", act = "eat", leave = 9 },
          { at = "work.counter", act = "work", leave = 16 },
          { at = "home.table", act = "eat" },
          { from = 21.5, at = "home.bed", act = "sleep" },
        } },
      },
      select = {
        { plan = "weekend", when = { weekday = { 5, 6 } } },
        { plan = "work" },
      },
    },
}
