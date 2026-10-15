-- lua/routines/core/clerk_fjerpen.lua - the daily routine of clerk_fjerpen (towns track; see docs: routine schema)
kind = "registry"
registry = "routines"

routines = {
    clerk_fjerpen = {
      home = "fjerpens_hytte", home_area = "traetoppen",
      work = "raadhuset", work_area = "traetoppen",
      priority = 3,
      shelter = "traetoppen.door_fjerpens_hytte",
      plans = {
        work = { blocks = {
          { from = 7.5, at = "traetoppen.door_fjerpens_hytte", act = "inside" },
          { from = 8.6667, at = "work.counter", act = "work", leave = 15 },
          { at = "traetoppen.t_bench1", act = "sit", leave = 17 },
          { at = "int_torvekroen.seat_a?", act = "sit", leave = 20.5 },
          { at = "traetoppen.door_fjerpens_hytte", act = "inside" },
        } },
        rest = { blocks = {
          { from = 9.5, at = "traetoppen.door_fjerpens_hytte", act = "inside" },
          { from = 11, at = "traetoppen.t_fire_n", act = "sit" },
          { from = 14, at = "traetoppen.u_terrace", act = "sit" },
          { from = 18, at = "int_torvekroen.seat_a?", act = "sit" },
          { from = 21.5, at = "traetoppen.door_fjerpens_hytte", act = "inside" },
        } },
      },
      select = {
        { plan = "rest", when = { weekday = { 5, 6 } } },
        { plan = "work" },
      },
    },
}
