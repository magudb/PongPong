-- lua/routines/core/bathkeeper_sofus.lua - the daily routine of bathkeeper_sofus (towns track; see docs: routine schema)
kind = "registry"
registry = "routines"

routines = {
    bathkeeper_sofus = {
      home = "badehuset", home_area = "traetoppen",
      work = "badehuset", work_area = "traetoppen",
      priority = 4,
      shelter = "home.bed",
      plans = {
        work = { blocks = {
          { from = 8, at = "home.bed", act = "eat" },
          { from = 9.75, at = "home.tub", act = "sit", leave = 21 },
          { at = "traetoppen.e_tub", act = "stand", leave = 22 },
          { at = "home.bed", act = "sleep" },
        } },
        sat = { blocks = {
          { from = 8, at = "home.bed", act = "eat" },
          { from = 9.75, at = "home.tub", act = "sit", leave = 21 },
          { at = "int_torvekroen.seat_e?", act = "sit", leave = 22.25 },
          { at = "home.bed", act = "sleep" },
        } },
      },
      select = {
        { plan = "sat", when = { weekday = { 5 } } },
        { plan = "work" },
      },
    },
}
