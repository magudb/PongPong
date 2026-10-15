-- tests/fixtures/towns/lua/fixture_buildings.lua - the buildings of the FIXTURE town of the towns tests (package T-towns-core): every shape of the opening-hours rule once.
-- kind = "registry", registry = "towns_fixture_buildings": never the real registry `buildings` (the tests point Hours.override_registry at it).
kind = "registry"
registry = "towns_fixture_buildings"

towns_fixture_buildings = {
  fx_bakery = {
    area = "fx_town", kind = "shop", name_key = "BLD_FX_BAKERY", interior = "int_fx_bakery", size = "M",
    shop = "fx_bread", keeper = "fx_baker",
    hours = { open = 7, close = 17, closed = { 0 } },
    wave = "core",
  },
  fx_inn = {
    area = "fx_town", kind = "public", name_key = "BLD_FX_INN", interior = "int_fx_inn", size = "L",
    keeper = "fx_host",
    hours = { open = 11, close = 23, closed = {}, overrides = { { weekday = { 0 }, open = 17, close = 23 } } },
    wave = "core",
  },
  fx_night_bar = {
    area = "fx_town", kind = "public", name_key = "BLD_FX_NIGHT_BAR", interior = "int_fx_night_bar", size = "S",
    keeper = "fx_host",
    hours = { open = 20, close = 1, closed = { 4 }, short_ok = true },
    wave = "core",
  },
  fx_lantern_house = {
    area = "fx_town", kind = "shop", name_key = "BLD_FX_LANTERN_HOUSE", interior = "int_fx_lantern_house", size = "S",
    shop = "fx_lanterns", keeper = "fx_lamplighter",
    hours = { open = 17, close = 25, closed = { 2 } },
    wave = "core",
  },
  fx_late_stall = {
    area = "fx_town", kind = "stall", name_key = "BLD_FX_LATE_STALL",
    shop = "fx_maps", keeper = "fx_lamplighter",
    hours = { open = 20, close = 25.5, closed = {}, short_ok = true },
    wave = "core",
  },
  fx_workshop = {
    area = "fx_town", kind = "shop", name_key = "BLD_FX_WORKSHOP", interior = "int_fx_workshop", size = "L",
    shop = "fx_timber", keeper = "fx_carpenter",
    hours = { open = 8, close = 16, closed = { 5, 6 } },
    wave = "core",
  },
  fx_market_stall = {
    area = "fx_town", kind = "stall", name_key = "BLD_FX_MARKET_STALL",
    shop = "fx_timber", keeper = "fx_carpenter",
    hours = { open = 10, close = 16, closed = { 0, 1, 2, 3, 4 } },
    wave = "core",
  },
  fx_clinic = {
    area = "fx_town", kind = "service", name_key = "BLD_FX_CLINIC", interior = "int_fx_clinic", size = "S",
    keeper = "fx_host",
    hours = { open = 12, close = 20, closed = {} },
    wave = "core",
  },
  fx_home = {
    area = "fx_town", kind = "home", name_key = "BLD_FX_HOME", interior = "int_fx_home", size = "S",
    owner = "fx_baker",
    wave = "core",
  },
  fx_nameplate = {
    area = "fx_town", kind = "home", name_key = "BLD_FX_NAMEPLATE",
    owner = "fx_host",
    wave = "core",
  },
}
