-- tests/fixtures/towns/lua/fixture_buildings_dup_b.lua - second file of the duplicate-id fixture: the later file wins, the duplicate is reported once.
kind = "registry"
registry = "towns_fixture_dups"

towns_fixture_dups = {
  fx_dup = { area = "fx_town", kind = "shop", source = "b", hours = { open = 10, close = 18, closed = {} } },
}
