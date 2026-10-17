-- Daily routine of rasmus; town extended content
kind = "registry"
registry = "routines"

routines = {
    rasmus = {
      home = "brummes_hus", home_area = "traetoppen",
      work = "brummes_vaerksted", work_area = "traetoppen",
      priority = 3,
      shelter = "home.table",
      hero_twin = "rasmus",
      plans = {
        work = { blocks = {
          { from = 6.75, at = "home.table", act = "eat" },
          { from = 7.8333, at = "work.work", act = "work", leave = 16 },
          { at = "traetoppen.t_bench1", act = "sit", leave = 17.5 },
          { from = 18.3333, at = "int_torvekroen.seat_c?", act = "sit" },
          { from = 21.5, at = "home.bed", act = "sleep" },
        } },
        stall = { blocks = {
          { from = 6.75, at = "home.table", act = "eat" },
          { from = 9.5, at = "traetoppen.t_stall", act = "work", leave = 16 },
          { at = "traetoppen.t_fire_e", act = "sit", leave = 17.5 },
          { from = 18.3333, at = "int_torvekroen.seat_c?", act = "sit" },
          { from = 21.5, at = "home.bed", act = "sleep" },
        } },
        rest = { blocks = {
          { from = 8, at = "home.table", act = "eat", leave = 9 },
          { at = "hyggebyen.torv_fountain_e", act = "sit", leave = 12.5 },
          { at = "hyggebyen.pond_dock", act = "fish", leave = 16 },
          { at = "hyggebyen.torv_bench2", act = "sit", leave = 18.5 },
          { at = "int_torvekroen.seat_c?", act = "sit" },
          { from = 22.5, at = "home.bed", act = "sleep" },
        } },
      },
      select = {
        { plan = "stall", when = { weekday = { 5 } } },
        { plan = "rest", when = { weekday = { 6 } } },
        { plan = "work" },
      },
    },
}
