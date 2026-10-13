-- tests/fixtures/lua/lint_bad_blocks.lua
-- An `if` without its `end`, and a stray `end` (data.lint_rules: unbalanced).

kind = "quest"
id = "lint_bad_blocks"

function open_block(context)
  if context.x then
    return { r = 1 }
  return { r = 2 }
end
