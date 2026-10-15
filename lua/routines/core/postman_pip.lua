-- lua/routines/core/postman_pip.lua - the daily routine of postman_pip (towns track; see docs: routine schema)
kind = "registry"
registry = "routines"

routines = {
    postman_pip = {
      home = "postkontoret", home_area = "traetoppen",
      speed_mult = 1.6, -- Courier pace; measured against the current bridge routes.
      work = "postkontoret", work_area = "traetoppen",
      priority = 5,
      shelter = "home.bed",
      plans = {
        work = { blocks = {
          { from = 6, at = "home.bed", act = "sleep", leave = 6.0833 },
          { from = 7.1667, at = "farm.pip_mailbox", act = "stand", leave = 7.5 },
          { at = "home.counter", act = "work", leave = 17 },
          { at = "traetoppen.t_fire_n", act = "sit", leave = 18 },
          { from = 19.3333, at = "int_torvekroen.seat_d?", act = "sit" },
          { from = 21.5, at = "home.bed", act = "sleep" },
        } },
        rest = { blocks = {
          { from = 6, at = "home.bed", act = "sleep", leave = 7 },
          { at = "traetoppen.t_fire_n", act = "sit", leave = 9.5 },
          { at = "traetoppen.b_bench", act = "sit", leave = 11 },
          { from = 12, at = "int_torvekroen.seat_d?", act = "sit" },
          { from = 15, at = "traetoppen.e_bench", act = "sit" },
          { from = 18, at = "traetoppen.t_fire_n", act = "sit" },
          { from = 21.5, at = "home.bed", act = "sleep" },
        } },
        town_only = { blocks = {
          { from = 6, at = "home.bed", act = "sleep", leave = 8.25 },
          { at = "home.counter", act = "work", leave = 17 },
          { at = "traetoppen.t_fire_n", act = "sit", leave = 18 },
          { from = 19.3333, at = "int_torvekroen.seat_d?", act = "sit" },
          { from = 21.5, at = "home.bed", act = "sleep" },
        } },
      },
      select = {
        { plan = "town_only", when = { day_max = 1 } },
        { plan = "rest", when = { weekday = { 6 } } },
        { plan = "work" },
      },
    },
}
