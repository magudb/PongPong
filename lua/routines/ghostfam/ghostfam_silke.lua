-- lua/routines/ghostfam/ghostfam_silke.lua - the daily routine of ghostfam_silke (design6: the ghost family on the 06:00-26:00 clock; hours past 24 are game hours of the SAME day (25.0 = 01:00); ghosts float: acts stand / lamp / sleep / patrol / hide, never sit; the plan wraps at the first place)
kind = "registry"
registry = "routines"

routines = {
    ghostfam_silke = {
      home = "gaestehytten", home_area = "traetoppen",
      priority = 4,
      -- Real baked paths need this pace to retain the 22:55/01:45 pins
      -- and the 1.4x walking-time margin on the late lamp round.
      speed_mult = 1.10,
      shelter = "home.table",
      plans = {
        work = { blocks = {
          { from = 6, at = "traetoppen.f_lamp", act = "lamp", leave = 6.4167 },
          { at = "traetoppen.f_bench", act = "stand", leave = 6.75 },
          { at = "home.bed", act = "sleep", leave = 17 },
          { at = "home.table", act = "eat" },
          { from = 18.4167, at = "traetoppen.t_ladder", act = "stand" },
          { from = 20.0833, at = "hyggebyen.round_s", act = "patrol", leave = 20.6667 },
          { at = "hyggebyen.round_e", act = "patrol", leave = 21.25 },
          { at = "hyggebyen.round_n", act = "patrol" },
          { from = 22.9167, at = "traetoppen.t_lamp", act = "lamp", stay = 0.2 },
          { at = "traetoppen.u_lamp", act = "lamp", stay = 0.2 },
          { at = "traetoppen.b_lamp", act = "lamp" },
          { from = 25.75, at = "traetoppen.f_lamp", act = "lamp" },
        } },
        family = { blocks = {
          { from = 6, at = "traetoppen.f_lamp", act = "lamp", leave = 6.4167 },
          { at = "traetoppen.f_bench", act = "stand", leave = 6.75 },
          { at = "home.bed", act = "sleep", leave = 17.1667 },
          { at = "home.table", act = "eat" },
          { from = 19, at = "traetoppen.t_fire_s", act = "stand", leave = 23 },
          { at = "traetoppen.f_lamp", act = "lamp" },
        } },
        fest = { blocks = {
          { from = 6, at = "traetoppen.f_lamp", act = "lamp", leave = 6.4167 },
          { at = "home.bed", act = "sleep", leave = 8.5 },
          { at = "home.table", act = "eat", leave = 9 },
          { at = "traetoppen.f_lamp", act = "lamp" },
          { from = 22.9167, at = "traetoppen.t_lamp", act = "lamp", stay = 0.2 },
          { at = "traetoppen.u_lamp", act = "lamp", stay = 0.2 },
          { at = "traetoppen.b_lamp", act = "lamp" },
          { from = 25.75, at = "traetoppen.f_lamp", act = "lamp" },
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
