-- tests/fixtures/lua/registry_buildings.lua
-- A SECOND registry (`fixture_buildings`) next to `fixture_routines`: registries do not leak into each other.

kind = "registry"
registry = "fixture_buildings"

fixture_buildings = {
  fixture_bakery = { area = "hyggebyen", kind = "shop", shop = "bakery", hours = { 6, 18 }, closed_weekday = 1 },
  fixture_night_inn = { area = "traetoppen", kind = "inn", hours = { 18, 26 }, closed_weekday = 0 },
}
