-- lua/routines/core/fairy_lily.lua - the daily routine of fairy_lily (towns track; see docs: routine schema)
kind = "registry"
registry = "routines"

routines = {
    fairy_lily = {
      home = "hyldeblomsts_hus", home_area = "hyggebyen",
      priority = 3,
      shelter = "home.table",
      plans = {
        work = { blocks = {
          { from = 7.5, at = "home.table", act = "eat" },
          { from = 9, at = "hyggebyen.torv_playground", act = "play" },
          { from = 12, at = "home.table", act = "eat" },
          { from = 14, at = "hyggebyen.torv_playground", act = "play" },
          { from = 17.5, at = "home.table", act = "eat" },
          { from = 20, at = "home.bed", act = "sleep" },
        } },
        visit = { blocks = {
          { from = 7.5, at = "home.table", act = "eat" },
          { from = 9, at = "hyggebyen.torv_playground", act = "play" },
          { from = 12, at = "home.table", act = "eat", leave = 12.75 },
          { at = "traetoppen.t_fire_s", act = "play", leave = 16.5 },
          { at = "home.table", act = "eat" },
          { from = 20.5, at = "home.bed", act = "sleep" },
        } },
      },
      select = {
        { plan = "visit", when = { weekday = { 5 } } },
        { plan = "work" },
      },
    },
}
