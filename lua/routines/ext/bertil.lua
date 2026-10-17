-- Daily routine of bertil; town extended content
kind = "registry"
registry = "routines"

routines = {
    bertil = {
      home = "koekkenhave_skuret", home_area = "traetoppen",
      priority = 3,
      shelter = "traetoppen.door_koekkenhave_skuret",
      hero_twin = "bertil",
      plans = {
        work = { blocks = {
          { from = 6.5, at = "traetoppen.door_koekkenhave_skuret", act = "inside" },
          { from = 7, at = "traetoppen.g_planter1", act = "tend" },
          { from = 10, at = "traetoppen.g_planter3", act = "tend" },
          { from = 12.5, at = "traetoppen.g_bench", act = "sit" },
          { from = 14, at = "traetoppen.g_planter2", act = "tend" },
          { from = 17.5, at = "traetoppen.t_fire_s", act = "sit" },
          { from = 19, at = "int_torvekroen.seat_e?", act = "sit" },
          { from = 21.5, at = "traetoppen.door_koekkenhave_skuret", act = "inside" },
        } },
        visit = { blocks = {
          { from = 7, at = "traetoppen.door_koekkenhave_skuret", act = "inside", leave = 8 },
          { at = "hyggebyen.bakery_terrace", act = "sit", leave = 11.5 },
          { at = "hyggebyen.torv_fountain_e", act = "sit", leave = 14.5 },
          { at = "hyggebyen.blossom_bench1", act = "sit", leave = 17.5 },
          { from = 19.5, at = "int_torvekroen.seat_e?", act = "sit" },
          { from = 22, at = "traetoppen.door_koekkenhave_skuret", act = "inside" },
        } },
      },
      select = {
        { plan = "visit", when = { weekday = { 6 } } },
        { plan = "work" },
      },
    },
}
