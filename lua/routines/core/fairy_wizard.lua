-- lua/routines/core/fairy_wizard.lua - the daily routine of fairy_wizard (towns track; see docs: routine schema)
kind = "registry"
registry = "routines"

routines = {
    fairy_wizard = {
      home = "troldmandstaarnet", home_area = "hyggebyen",
      work = "troldmandstaarnet", work_area = "hyggebyen",
      priority = 4,
      shelter = "hyggebyen.door_troldmandstaarnet",
      plans = {
        work = { blocks = {
          { from = 8, at = "hyggebyen.door_troldmandstaarnet", act = "inside", leave = 10.5 },
          { at = "home.counter", act = "work", leave = 19 },
          { at = "hyggebyen.round_w", act = "patrol", leave = 20.5 },
          { at = "hyggebyen.door_troldmandstaarnet", act = "inside" },
        } },
        lesson = { blocks = {
          { from = 8, at = "hyggebyen.door_troldmandstaarnet", act = "inside" },
          { from = 10, at = "hyggebyen.torv_playground", act = "stand" },
          { from = 12, at = "hyggebyen.blossom_bench2", act = "sit" },
          { from = 15, at = "hyggebyen.round_w", act = "patrol" },
          { from = 21, at = "hyggebyen.door_troldmandstaarnet", act = "inside" },
        } },
      },
      select = {
        { plan = "lesson", when = { weekday = { 1 } } },
        { plan = "work" },
      },
    },
}
