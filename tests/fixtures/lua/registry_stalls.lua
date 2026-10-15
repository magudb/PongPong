-- tests/fixtures/lua/registry_stalls.lua
-- A third registry (`fixture_stalls`) that reuses the id `fixture_baker` of the registry `fixture_routines`: an id is
-- claimed per registry, so this is NOT a duplicate (tests/sections/data_registry.gd checks that data_report stays quiet).

kind = "registry"
registry = "fixture_stalls"

fixture_stalls = {
  fixture_baker = { stall = "bread", weekday = { 5, 6 } },
}
