-- Daily routine of innkeeper_kvak; town extended content
kind = "registry"
registry = "routines"

routines = {
    innkeeper_kvak = {
      home = "torvekroen", home_area = "traetoppen",
      work = "torvekroen", work_area = "traetoppen",
      priority = 4,
      shelter = "home.seat_a",
      plans = {
        work = { blocks = {
          { from = 7, at = "home.bed", act = "eat", leave = 9 },
          { at = "home.counter", act = "work", leave = 23 },
          { at = "home.bed", act = "sleep" },
        } },
        mon = { blocks = {
          { from = 6, at = "home.bed", act = "eat", leave = 7.5 },
          { at = "hyggebyen.pond_dock", act = "fish", leave = 12 },
          { at = "hyggebyen.torv_fountain_s", act = "sit", leave = 13.5 },
          { at = "hyggebyen.pond_dock", act = "fish", leave = 15.75 },
          { at = "home.counter", act = "work", leave = 23 },
          { at = "home.bed", act = "sleep" },
        } },
      },
      select = {
        { plan = "mon", when = { weekday = { 0 } } },
        { plan = "work" },
      },
    },
}
