-- tests/fixtures/lua/registry_bad_notable.lua
-- BAD on purpose (finding registry_header): the header names a registry (`fixture_ghosts`) but the file has no top-level
-- table of that name (it was spelled `fixture_ghost`). Nothing from this file is registered.

kind = "registry"
registry = "fixture_ghosts"

fixture_ghost = {
  fixture_spirit = { home = "attic" },
}
