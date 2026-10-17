-- Daily routine of bodil; town extended content
kind = "registry"
registry = "routines"

routines = {
    bodil = {
      home = "bageriet", home_area = "hyggebyen",
      priority = 3,
      shelter = "hyggebyen.door_bageriet",
      hero_twin = "bodil",
      plans = {
        work = { blocks = {
          { from = 6, at = "hyggebyen.door_bageriet", act = "inside", leave = 6.5 },
          { at = "home.work", act = "work", leave = 14 },
          { at = "hyggebyen.torv_fountain_w", act = "sit", leave = 16 },
          { at = "hyggebyen.pond_dock", act = "fish", leave = 18 },
          { at = "hyggebyen.blossom_bench1", act = "sit", leave = 19.5 },
          { at = "hyggebyen.door_bageriet", act = "inside" },
        } },
        mon = { blocks = {
          { from = 8, at = "hyggebyen.door_bageriet", act = "inside" },
          { from = 10, at = "hyggebyen.blossom_bench1", act = "sit" },
          { from = 13, at = "hyggebyen.torv_fountain_w", act = "sit" },
          { from = 17, at = "hyggebyen.bakery_terrace", act = "sit" },
          { from = 20, at = "hyggebyen.door_bageriet", act = "inside" },
        } },
      },
      select = {
        { plan = "mon", when = { weekday = { 0 } } },
        { plan = "work" },
      },
    },
}
