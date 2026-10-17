-- Daily routine of lamplighter_kiki; town extended content
kind = "registry"
registry = "routines"

routines = {
    lamplighter_kiki = {
      home = "kikis_hytte", home_area = "traetoppen",
      priority = 3,
      shelter = "home.table",
      hero_twin = "kiki",
      plans = {
        work = { blocks = {
          { from = 6.5, at = "home.table", act = "eat" },
          { from = 8, at = "traetoppen.t_fire_w", act = "sit" },
          { from = 9.25, at = "traetoppen.g_bench", act = "sit" },
          { from = 11.75, at = "traetoppen.t_bench1", act = "sit" },
          { from = 13.5, at = "traetoppen.e_bench", act = "sit" },
          { from = 15.5, at = "traetoppen.u_terrace", act = "sit" },
          { from = 17.5, at = "traetoppen.t_lamp", act = "lamp", stay = 0.1 },
          { at = "traetoppen.u_lamp", act = "lamp", stay = 0.1 },
          { at = "traetoppen.e_lamp", act = "lamp", stay = 0.1 },
          { at = "traetoppen.b_lamp", act = "lamp", stay = 0.1 },
          { at = "int_torvekroen.seat_e?", act = "sit", leave = 21.5 },
          { at = "home.bed", act = "sleep" },
        } },
        rest = { blocks = {
          { from = 8.5, at = "home.table", act = "eat" },
          { from = 10, at = "traetoppen.t_bench2", act = "sit" },
          { from = 13, at = "traetoppen.e_bench", act = "sit" },
          { from = 16.5, at = "traetoppen.b_bench", act = "sit" },
          { from = 21.5, at = "home.bed", act = "sleep" },
        } },
      },
      select = {
        { plan = "rest", when = { weekday = { 6 } } },
        { plan = "work" },
      },
    },
}
