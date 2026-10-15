-- lua/routines/core/gardener_hoppe.lua - the daily routine of gardener_hoppe (towns track; see docs: routine schema)
kind = "registry"
registry = "routines"

routines = {
    gardener_hoppe = {
      home = "hoppe_hut", home_area = "traetoppen",
      priority = 4,
      shelter = "home.table",
      plans = {
        work = { blocks = {
          { from = 6.5, at = "home.table", act = "eat" },
          { from = 7.25, at = "traetoppen.a_beds1", act = "tend" },
          { from = 10.5, at = "traetoppen.a_beds2", act = "tend" },
          { from = 12.5, at = "traetoppen.a_bench", act = "sit" },
          { from = 13.5, at = "traetoppen.a_beds1", act = "tend", leave = 16.5 },
          { at = "traetoppen.t_fire_n", act = "sit", leave = 18.1 },
          { at = "home.table", act = "eat" },
          { from = 20.5, at = "home.hearth", act = "stand" },
          { from = 22, at = "home.bed", act = "sleep" },
        } },
        rest = { blocks = {
          { from = 7.5, at = "home.table", act = "eat" },
          { from = 9, at = "traetoppen.a_bench", act = "sit" },
          { from = 11, at = "traetoppen.t_fire_s", act = "sit" },
          { from = 13, at = "int_torvekroen.seat_a?", act = "sit" },
          { from = 15.5, at = "traetoppen.u_terrace", act = "sit" },
          { from = 18, at = "home.table", act = "eat" },
          { from = 22, at = "home.bed", act = "sleep" },
        } },
        farm_visit = { blocks = {
          { from = 6.5, at = "home.table", act = "eat" },
          { from = 7.25, at = "traetoppen.a_beds1", act = "tend" },
          { from = 11.5, at = "traetoppen.a_bench", act = "sit", leave = 13.0 },
          { from = 15, at = "farm.hoppe_fence", act = "stand", leave = 16 },
          { at = "traetoppen.t_fire_n", act = "sit", leave = 18.1 },
          { at = "home.table", act = "eat" },
          { from = 22, at = "home.bed", act = "sleep" },
        } },
        inn = { blocks = {
          { from = 6.5, at = "home.table", act = "eat" },
          { from = 7.25, at = "traetoppen.a_beds1", act = "tend" },
          { from = 10.5, at = "traetoppen.a_beds2", act = "tend" },
          { from = 12.5, at = "traetoppen.a_bench", act = "sit" },
          { from = 13.5, at = "traetoppen.a_beds1", act = "tend", leave = 17 },
          { at = "home.table", act = "eat" },
          { from = 19.5, at = "int_torvekroen.seat_b?", act = "sit" },
          { from = 22.75, at = "home.bed", act = "sleep" },
        } },
      },
      select = {
        { plan = "inn", when = { weekday = { 4, 5 } } },
        { plan = "farm_visit", when = { weekday = { 2 }, min_hearts = 2 } },
        { plan = "rest", when = { weekday = { 6 } } },
        { plan = "work" },
      },
    },
}
