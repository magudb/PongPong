kind = "registry"
registry = "routines"
routines = { loop_neighbour = {
 home = "loop_shop", home_area = "hyggebyen", work = "loop_shop", work_area = "hyggebyen",
 shelter = "home.counter", priority = 10,
 plans = { daily = { blocks = { { from = 6, at = "home.bed", act = "sleep" }, { from = 9, at = "home.counter", act = "work", leave = 21 }, { at = "home.bed", act = "sleep" } } } },
 select = { { plan = "daily" } },
} }
