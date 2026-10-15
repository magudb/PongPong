-- lua/routines/core/fairy_king.lua - the daily routine of fairy_king (towns track; see docs: routine schema)
kind = "registry"
registry = "routines"

routines = {
    fairy_king = {
      home = "fekongens_hus", home_area = "hyggebyen",
      work = "fekongens_hus", work_area = "hyggebyen",
      priority = 3,
      shelter = "home.throne",
      plans = {
        work = { blocks = {
          { from = 6, at = "home.throne", act = "sit", leave = 17 },
          { at = "hyggebyen.king_balcony", act = "sit", leave = 19 },
          { at = "home.throne", act = "sit" },
        } },
      },
      select = {
        { plan = "work" },
      },
    },
}
