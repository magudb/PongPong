-- tests/fixtures/lua/p25_float_index.lua
-- Indexing a table by a number that arrives as a float (a save or the world flags went through JSON): Lua normalises an
-- integral float key to the integer, so names[2.0] is names[2] (LUA-07: the runtime answered nil).
kind = "dialogue"
id = "p25"

function get_dialogue(context)
  local names = { "spring", "summer", "autumn", "winter" }
  return names[context.stage]
end

function by_key(context)
  local prices = { [1] = "low", [2] = "mid", [3] = "high" }
  return prices[context.stage]
end
