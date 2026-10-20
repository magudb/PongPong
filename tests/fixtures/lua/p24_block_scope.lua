-- tests/fixtures/lua/p24_block_scope.lua
-- A `local` inside a block ends with the block and only shadows the outer name there; an assignment inside a block sets the
-- outer local (LUA-07: the runtime had one flat scope per call, so the inner local overwrote the outer one).
kind = "dialogue"
id = "p24"

function get_dialogue(context)
  local tier = 1
  if context.up then
    local tier = 5
    if tier == 5 then
      api.set_flag("inner_tier_seen", true)
    end
  end
  return tier
end

function assign_outer(context)
  local tier = 1
  if context.up then
    tier = 5
  end
  return tier
end

function shadow_param(context)
  if context.up then
    local context = "inner"
    api.set_flag("shadowed", context)
  end
  return context.up or false
end
