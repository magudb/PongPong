-- Daily routine of cub_bamse; town extended content
kind = "registry"
registry = "routines"

routines = {
    cub_bamse = {
      home = "vagthytten", home_area = "traetoppen",
      priority = 2,
      shelter = "home.table",
      plans = {
        work = { blocks = {
          { from = 7, at = "home.table", act = "eat" },
          { from = 8.5, at = "traetoppen.t_fire_s", act = "play" },
          { from = 11.5, at = "home.table", act = "eat" },
          { from = 13, at = "traetoppen.b_bench", act = "play" },
          { from = 17.5, at = "home.table", act = "eat" },
          { from = 20, at = "home.bed", act = "sleep" },
        } },
        visit = { blocks = {
          { from = 7, at = "home.table", act = "eat" },
          { from = 8.5, at = "traetoppen.t_fire_s", act = "play" },
          { from = 11.5, at = "home.table", act = "eat", leave = 12.5 },
          { at = "hyggebyen.torv_playground", act = "play", leave = 16 },
          { at = "home.table", act = "eat" },
          { from = 20, at = "home.bed", act = "sleep" },
        } },
      },
      select = {
        { plan = "visit", when = { weekday = { 5 } } },
        { plan = "work" },
      },
    },
}
