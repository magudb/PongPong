-- tests/fixtures/lua/registry_routines_b.lua
-- The second file of the registry `fixture_routines`: one NEW id (fixture_mayor) and one id that registry_routines_a.lua
-- already claimed (fixture_baker): the duplicate is reported in LuaRuntime.data_report and the later file wins.

kind = "registry"
registry = "fixture_routines"

fixture_routines = {
  fixture_mayor = {
    home = "mayor_house", home_area = "hyggebyen", priority = 5,
    plans = { work = { blocks = { { from = 9.5, at = "int_townhall.desk", act = "work", leave = 16 } } } },
    select = { { plan = "work", when = { weekday = { 1, 2, 3 }, min_hearts = 0 } } } },

  fixture_baker = {
    home = "bakery", home_area = "hyggebyen", priority = 3, source = "b",
    plans = { work = { blocks = { { from = 4.5, at = "int_bakery.oven", act = "work" } } } },
    select = { { plan = "work" } } },
}
