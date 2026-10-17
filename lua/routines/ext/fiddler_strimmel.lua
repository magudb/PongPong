-- Daily routine of fiddler_strimmel; town extended content
kind = "registry"
registry = "routines"

routines = {
    fiddler_strimmel = {
      home = "musikstuen", home_area = "traetoppen",
      priority = 2,
      shelter = "home.table",
      plans = {
        work = { blocks = {
          { from = 8, at = "home.table", act = "eat" },
          { from = 10, at = "traetoppen.f_bench", act = "play" },
          { from = 13, at = "home.hearth", act = "play" },
          { from = 16, at = "traetoppen.t_fire_w", act = "play" },
          { from = 18.5, at = "int_torvekroen.seat_c?", act = "sit" },
          { from = 21.5, at = "home.bed", act = "sleep" },
        } },
        gig = { blocks = {
          { from = 8, at = "home.table", act = "eat" },
          { from = 10, at = "traetoppen.f_bench", act = "play" },
          { from = 14, at = "home.hearth", act = "play" },
          { from = 18.5, at = "int_torvekroen.stage?", act = "play" },
          { from = 22.5, at = "home.bed", act = "sleep" },
        } },
        busk = { blocks = {
          { from = 8, at = "home.table", act = "eat", leave = 9.5 },
          { at = "hyggebyen.torv_fountain_w", act = "play", leave = 13 },
          { at = "traetoppen.t_fire_w", act = "play", leave = 17.5 },
          { from = 18.5, at = "int_torvekroen.stage?", act = "play" },
          { from = 22.5, at = "home.bed", act = "sleep" },
        } },
      },
      select = {
        { plan = "busk", when = { weekday = { 5 } } },
        { plan = "gig", when = { weekday = { 4 } } },
        { plan = "work" },
      },
    },
}
