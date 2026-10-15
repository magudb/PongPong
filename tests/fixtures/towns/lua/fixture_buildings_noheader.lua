-- tests/fixtures/towns/lua/fixture_buildings_noheader.lua - a registry file WITHOUT its `registry = ` header: the lint finding registry_header, nothing registers.
kind = "registry"

towns_fixture_headless = {
  fx_nobody = { area = "fx_town", kind = "shop", hours = { open = 8, close = 16, closed = {} } },
}
