-- tests/fixtures/towns/lua/fixture_citizens.lua - the SIX citizens of the fixture town (package T-towns-core): who keeps which fixture building, who lives where.
-- A registry of its own (`towns_fixture_citizens`); T-routes and T-director reuse the fixture town for their validators.
kind = "registry"
registry = "towns_fixture_citizens"

towns_fixture_citizens = {
  fx_baker = { home = "fx_home", work = "fx_bakery", closed = { 0 }, routine = true },
  fx_host = { home = "fx_nameplate", work = "fx_inn", closed = {}, routine = true },
  fx_lamplighter = { home = "fx_nameplate", work = "fx_lantern_house", closed = { 2 }, routine = true },
  fx_carpenter = { home = "fx_nameplate", work = "fx_workshop", closed = { 5, 6 }, routine = true },
  fx_child = { home = "fx_home", closed = {}, routine = true },
  fx_visitor = { home = "fx_nameplate", closed = { 6 }, routine = true },
}
