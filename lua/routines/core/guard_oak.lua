-- lua/routines/core/guard_oak.lua - the daily routine of guard_oak (towns track; see docs: routine schema)
kind = "registry"
registry = "routines"

routines = {
    guard_oak = {
      home = "vagthytten", home_area = "traetoppen",
      work = "vagthytten", work_area = "traetoppen",
      priority = 3,
      shelter = "home.table",
      plans = {
        work = { blocks = {
          { from = 6.5, at = "home.table", act = "eat" },
          { from = 7.5, at = "traetoppen.b_lift", act = "guard", leave = 12 },
          { at = "traetoppen.b_bench", act = "sit", leave = 12.75 },
          { at = "traetoppen.b_lift", act = "guard", leave = 15 },
          { at = "traetoppen.t_fire_e", act = "patrol", leave = 15.6667 },
          { at = "traetoppen.b_lift", act = "guard", leave = 17.5 },
          { from = 18.3333, at = "int_torvekroen.seat_b?", act = "sit" },
          { from = 21, at = "home.table", act = "eat" },
          { from = 22, at = "home.bed", act = "sleep" },
        } },
        inn = { blocks = {
          { from = 6.5, at = "home.table", act = "eat" },
          { from = 7.5, at = "traetoppen.b_lift", act = "guard", leave = 12 },
          { at = "traetoppen.b_bench", act = "sit", leave = 12.75 },
          { at = "traetoppen.b_lift", act = "guard", leave = 17 },
          { from = 17.75, at = "int_torvekroen.seat_a?", act = "sit" },
          { from = 22.5, at = "home.bed", act = "sleep" },
        } },
      },
      select = {
        { plan = "inn", when = { weekday = { 5 } } },
        { plan = "work" },
      },
    },
}
