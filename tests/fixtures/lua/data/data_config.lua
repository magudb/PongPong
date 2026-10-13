-- tests/fixtures/lua/data/data_config.lua
-- A config file in a directory that is NOT lua/config: the `kind` header decides (addendum 3: lua/data/** works in any directory).

kind = "config"

config = {
  fixture_numbers = {
    small = 3,
    ratio = 0.25,
    negative = -7,
    list = { 1, 2, 3 },
    names = { "a", "b" },
    nested = { deep = { deeper = { leaf = "x" } } },
    table_list = { { id = "one", n = 1 }, { id = "two", n = 2 } },
    flag_on = true,
    flag_off = false,
  },
}
