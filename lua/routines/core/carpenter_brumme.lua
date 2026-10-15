-- lua/routines/core/carpenter_brumme.lua - the daily routine of carpenter_brumme (towns track; see docs: routine schema)
kind = "registry"
registry = "routines"

routines = {
    carpenter_brumme = {
      home = "brummes_hus", home_area = "traetoppen",
      work = "brummes_vaerksted", work_area = "traetoppen",
      priority = 4,
      shelter = "home.table",
      plans = {
        work = { blocks = {
          { from = 6.5, at = "home.table", act = "eat" },
          { from = 7.75, at = "work.counter", act = "work", leave = 16 },
          { at = "traetoppen.c_bench", act = "sit", leave = 17.25 },
          { at = "home.table", act = "eat" },
          { from = 19, at = "home.hearth", act = "stand" },
          { from = 21.5, at = "home.bed", act = "sleep" },
        } },
        stall = { blocks = {
          { from = 6.5, at = "home.table", act = "eat" },
          { from = 9.5, at = "traetoppen.t_stall", act = "work", leave = 16 },
          { at = "traetoppen.t_fire_w", act = "sit", leave = 17.5 },
          { from = 18.3333, at = "int_torvekroen.seat_a?", act = "sit" },
          { from = 21.5, at = "home.bed", act = "sleep" },
        } },
        inn = { blocks = {
          { from = 6.5, at = "home.table", act = "eat" },
          { from = 7.75, at = "work.counter", act = "work", leave = 16 },
          { at = "traetoppen.c_bench", act = "sit", leave = 17.5 },
          { from = 18.25, at = "int_torvekroen.seat_a?", act = "sit" },
          { from = 22, at = "home.bed", act = "sleep" },
        } },
      },
      select = {
        { plan = "stall", when = { weekday = { 5, 6 } } },
        { plan = "inn", when = { weekday = { 4 } } },
        { plan = "work" },
      },
    },
}
