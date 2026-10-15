-- lua/routines/core/cat_morfar_mis.lua - the daily routine of cat_morfar_mis (towns track; see docs: routine schema)
kind = "registry"
registry = "routines"

routines = {
    cat_morfar_mis = {
      home = "pippins_hus", home_area = "hyggebyen",
      priority = 2,
      shelter = "home.hearth",
      gate = { done_quest = "lost_cat", or_day = 60 },
      plans = {
        work = { blocks = {
          { from = 8, at = "home.hearth", act = "sit" },
          { from = 10, at = "hyggebyen.torv_bench2", act = "sit" },
          { from = 13, at = "home.hearth", act = "sit" },
          { from = 15.5, at = "hyggebyen.blossom_bench2", act = "sit" },
          { from = 18, at = "home.hearth", act = "sit" },
          { from = 20, at = "home.bed", act = "sleep" },
        } },
      },
      select = {
        { plan = "work" },
      },
    },
}
