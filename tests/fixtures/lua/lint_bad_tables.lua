-- tests/fixtures/lua/lint_bad_tables.lua
-- Table constructors the reader cannot honour: every one must be reported (data.lint_rules).

kind = "config"

config = {
  mixed = { a = 1, "positional" },
  with_nil = { present = 1, absent = nil },
  with_name = { speed = some_variable },
  with_call = { when = compute(3) },
  with_sum = { total = 1 + 2 },
  fine = { a = 1, b = "two", c = { 3, 4 }, d = -5, e = true },
}
