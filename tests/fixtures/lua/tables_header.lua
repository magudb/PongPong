-- tests/fixtures/lua/tables_header.lua
-- The `tables` header names top-level tables that belong to the file: alpha and beta exist, gamma does not (reported).

kind = "config"
tables = { "alpha", "beta", "gamma" }

alpha = { x = 1 }
beta = { y = { 1, 2, 3 } }

config = {
  header_fixture = { loaded = true },
}
