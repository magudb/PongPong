-- lua/routines/core/beekeeper_birk.lua - the daily routine of beekeeper_birk (towns track; see docs: routine schema)
kind = "registry"
registry = "routines"

routines = {
    beekeeper_birk = {
      home = "birks_bistade", home_area = "hyggebyen",
      priority = 3,
      shelter = "home.table",
      plans = {
        honey = { blocks = {
          { from = 6.5, at = "home.table", act = "eat", leave = 7.1667 },
          { at = "int_bageriet.cust2", act = "stand", stay = 0.1667 },
          { at = "hyggebyen.bees1", act = "tend", leave = 11.5 },
          { at = "hyggebyen.bees2", act = "tend", leave = 13 },
          { at = "hyggebyen.blossom_bench2", act = "sit", leave = 14 },
          { at = "hyggebyen.bees1", act = "tend", leave = 17.5 },
          { at = "hyggebyen.torv_fountain_s", act = "sit", leave = 19 },
          { at = "home.table", act = "eat" },
          { from = 21.5, at = "home.bed", act = "sleep" },
        } },
        sun = { blocks = {
          { from = 8, at = "home.table", act = "eat" },
          { from = 9.5, at = "hyggebyen.bees1", act = "tend" },
          { from = 12, at = "hyggebyen.blossom_bench2", act = "sit" },
          { from = 14, at = "home.table", act = "eat" },
          { from = 21.5, at = "home.bed", act = "sleep" },
        } },
        work = { blocks = {
          { from = 6.5, at = "home.table", act = "eat" },
          { from = 7.5, at = "hyggebyen.bees1", act = "tend" },
          { from = 11.5, at = "hyggebyen.bees2", act = "tend" },
          { from = 13, at = "hyggebyen.blossom_bench2", act = "sit" },
          { from = 14, at = "hyggebyen.bees1", act = "tend" },
          { from = 17.5, at = "hyggebyen.torv_fountain_s", act = "sit" },
          { from = 19, at = "home.table", act = "eat" },
          { from = 21.5, at = "home.bed", act = "sleep" },
        } },
        inn = { blocks = {
          { from = 6.5, at = "home.table", act = "eat" },
          { from = 7.5, at = "hyggebyen.bees1", act = "tend" },
          { from = 11.5, at = "hyggebyen.bees2", act = "tend" },
          { from = 14, at = "hyggebyen.bees1", act = "tend", leave = 16.5 },
          { at = "home.table", act = "eat", leave = 18 },
          { at = "int_torvekroen.seat_f?", act = "sit" },
          { from = 23, at = "home.bed", act = "sleep" },
        } },
      },
      select = {
        { plan = "inn", when = { weekday = { 4 } } },
        { plan = "sun", when = { weekday = { 6 } } },
        { plan = "honey", when = { weekday = { 1, 2, 3, 5 } } },
        { plan = "work" },
      },
    },
}
