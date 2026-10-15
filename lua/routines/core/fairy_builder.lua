-- lua/routines/core/fairy_builder.lua - the daily routine of fairy_builder (towns track; see docs: routine schema)
kind = "registry"
registry = "routines"

routines = {
    fairy_builder = {
      home = "toemmerhandlen", home_area = "hyggebyen",
      work = "toemmerhandlen", work_area = "hyggebyen",
      priority = 4,
      shelter = "hyggebyen.door_toemmerhandlen",
      plans = {
        work = { blocks = {
          { from = 6.5, at = "hyggebyen.door_toemmerhandlen", act = "inside", leave = 7.5 },
          { at = "home.counter", act = "work", leave = 16 },
          { at = "hyggebyen.market_row2", act = "stand", leave = 17.5 },
          { at = "hyggebyen.torv_bench1", act = "sit", leave = 20.5 },
          { at = "hyggebyen.door_toemmerhandlen", act = "inside" },
        } },
        rest = { blocks = {
          { from = 8.5, at = "hyggebyen.door_toemmerhandlen", act = "inside" },
          { from = 10, at = "hyggebyen.market_row2", act = "stand" },
          { from = 13, at = "hyggebyen.torv_bench1", act = "sit" },
          { from = 15.5, at = "hyggebyen.blossom_bench2", act = "sit" },
          { from = 16.5, at = "hyggebyen.door_toemmerhandlen", act = "inside" },
        } },
      },
      select = {
        { plan = "rest", when = { weekday = { 4 } } },
        { plan = "work" },
      },
    },
}
