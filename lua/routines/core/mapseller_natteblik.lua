-- lua/routines/core/mapseller_natteblik.lua - the daily routine of mapseller_natteblik (towns track; see docs: routine schema)
kind = "registry"
registry = "routines"

routines = {
    mapseller_natteblik = {
      home = "natteblik_vinduet", home_area = "traetoppen",
      work = "natteblik_vinduet", work_area = "traetoppen",
      priority = 3,
      shelter = "traetoppen.e_bat_window",
      plans = {
        work = { blocks = {
          { from = 6, at = "nowhere", act = "away", leave = 19.5 },
          { at = "traetoppen.e_bat_window", act = "perch", leave = 23.5 },
          { at = "nowhere", act = "away" },
        } },
      },
      select = {
        { plan = "work" },
      },
    },
}
