-- lua/routines/ghostfam/ghostfam_dyne.lua - the daily routine of ghostfam_dyne (design6: the ghost family on the 06:00-26:00 clock; hours past 24 are game hours of the SAME day (25.0 = 01:00); ghosts float: acts stand / lamp / sleep / patrol / hide, never sit; the plan wraps at the first place)
kind = "registry"
registry = "routines"

routines = {
    ghostfam_dyne = {
      home = "gaestehytten", home_area = "traetoppen",
      priority = 3,
      shelter = "home.table",
      plans = {
        work = { blocks = {
          { from = 6, at = "traetoppen.f_bench", act = "stand", leave = 6.6667 },
          { at = "home.bed", act = "sleep", leave = 16.5 },
          { at = "home.table", act = "eat", leave = 17.25 },
          { at = "traetoppen.t_fire_e", act = "stand", leave = 22.5 },
          { at = "traetoppen.f_bench", act = "stand" },
        } },
        family = { blocks = {
          { from = 6, at = "traetoppen.f_bench", act = "stand", leave = 6.6667 },
          { at = "home.bed", act = "sleep", leave = 16.5 },
          { at = "home.table", act = "eat", leave = 17.25 },
          { at = "traetoppen.t_fire_e", act = "stand", leave = 23 },
          { at = "traetoppen.f_bench", act = "stand" },
        } },
        fest = { blocks = {
          { from = 6, at = "traetoppen.f_bench", act = "stand", leave = 6.6667 },
          { at = "home.bed", act = "sleep", leave = 8.5 },
          { at = "home.table", act = "eat", leave = 9 },
          { at = "traetoppen.f_bench", act = "stand" },
        } },
      },
      select = {
        { plan = "fest", when = { festival = "blomsterfesten" } },
        { plan = "fest", when = { festival = "honningdagen" } },
        { plan = "fest", when = { festival = "midsommerlanterner" } },
        { plan = "fest", when = { festival = "badedagen" } },
        { plan = "fest", when = { festival = "hoestfesten" } },
        { plan = "fest", when = { festival = "maanemarkedet" } },
        { plan = "fest", when = { festival = "vinterlysene" } },
        { plan = "fest", when = { festival = "bagedagen" } },
        { plan = "fest", when = { festival = "aarsskiftet" } },
        { plan = "family", when = { weekday = { 2 } } },
        { plan = "work" },
      },
    },
}
