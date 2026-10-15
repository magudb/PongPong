-- lua/routines/core/appraiser_fru_ugle.lua - the daily routine of appraiser_fru_ugle (towns track; see docs: routine schema)
kind = "registry"
registry = "routines"

routines = {
    appraiser_fru_ugle = {
      home = "uglehulen", home_area = "traetoppen",
      work = "uglehulen", work_area = "traetoppen",
      priority = 4,
      shelter = "home.perch",
      plans = {
        work = { blocks = {
          { from = 7, at = "home.perch", act = "perch" },
          { from = 11.75, at = "home.counter", act = "work", leave = 20 },
          { at = "traetoppen.a_ugle_perch", act = "perch", leave = 22 },
          { at = "home.perch", act = "sleep" },
        } },
        field = { blocks = {
          { from = 7, at = "home.perch", act = "perch", leave = 9 },
          { at = "away:traetoppen.gate_skovlift", act = "away", leave = 17 },
          { at = "traetoppen.a_ugle_perch", act = "perch", leave = 22 },
          { at = "home.perch", act = "sleep" },
        } },
      },
      select = {
        { plan = "field", when = { weekday = { 0, 3 } } },
        { plan = "work" },
      },
    },
}
