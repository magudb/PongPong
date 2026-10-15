-- tests/fixtures/lua/registry_bad_noheader.lua
-- BAD on purpose (finding registry_header): kind = "registry" but no `registry = "<name>"` header, so nobody can say which
-- registry the table belongs to. Nothing from this file is registered.

kind = "registry"

fixture_orphans = {
  fixture_nobody = { home = "nowhere" },
}
