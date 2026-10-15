-- tests/fixtures/towns/lua/fixture_buildings_dup_a.lua - first file of the duplicate-id fixture: `fx_dup` is defined here AND in fixture_buildings_dup_b.lua (a claim error, not a lint finding).
kind = "registry"
registry = "towns_fixture_dups"

towns_fixture_dups = {
  fx_dup = { area = "fx_town", kind = "shop", source = "a", hours = { open = 8, close = 16, closed = {} } },
  fx_only_a = { area = "fx_town", kind = "service", hours = { open = 9, close = 15, closed = { 6 } } },
}
