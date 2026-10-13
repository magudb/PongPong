-- tests/fixtures/lua/lint_stdlib.lua
-- Library functions and method calls that do not exist in the interpreted subset (data.lint_rules: stdlib, method_call).

kind = "dialogue"
id = "lint_stdlib"

function get_dialogue(context)
  local n = tonumber("5")
  for _, v in ipairs({ 1, 2 }) do
    api.log(tostring(v))
  end
  local up = ("abc"):upper()
  return { n = 1 }
end
