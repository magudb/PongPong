-- tests/fixtures/lua/registry_routines_a.lua
-- A registry file (kind = "registry", addendum 4.8 / 8.6): the data of one citizen's day. The first of two files that feed
-- the SAME registry `fixture_routines`; tests/sections/data_registry.gd loads it through LuaRuntime.load_file.
-- Shape facts the loader must keep: floats stay floats (6.5), integers stay integers (22), arrays of tables stay arrays,
-- `{ 6 }` is an array of numbers. The Lua key `until` is a reserved word: blocks use leave / stay / from.

kind = "registry"
registry = "fixture_routines"

fixture_routines = {
  fixture_gardener = {
    home = "hoppe_hut", home_area = "traetoppen", priority = 4, shelter = "home.table",
    plans = {
      work = { blocks = {
        { from = 6.5,  at = "home.table",         act = "eat" },
        { from = 7.25, at = "traetoppen.a_beds1", act = "tend" },
        { from = 13.5, at = "traetoppen.a_beds1", act = "tend", leave = 16.5 },
        { from = 22,   at = "home.bed",           act = "sleep" } } },
      rest = { blocks = { { from = 8, at = "home.table", act = "sit", stay = 2 } } } },
    select = { { plan = "rest", when = { weekday = { 6 } } }, { plan = "work" } } },

  fixture_baker = {
    home = "bakery", home_area = "hyggebyen", priority = 3, source = "a",
    plans = { work = { blocks = { { from = 5, at = "int_bakery.oven", act = "work" } } } },
    select = { { plan = "work" } } },
}
