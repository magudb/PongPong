-- tests/fixtures/lua/semantics.lua
-- Lua semantics the interpreter must honour inside the subset (data.semantics_*): truthiness, mixed-type comparison,
-- precedence, parentheses, early return order, the world flag as bare identifier, get_flag as a value.

kind = "quest"
id = "semantics"

function zero_is_true(context)
  if 0 then
    return { r = "true" }
  end
  return { r = "false" }
end

function empty_string_is_true(context)
  if "" then
    return { r = "true" }
  end
  return { r = "false" }
end

function nil_and_false_are_false(context)
  local a = context.missing
  local b = context.off
  if a or b then
    return { r = "some" }
  end
  return { r = "none" }
end

function mixed_compare(context)
  local f = context.missing or false
  if f == 3 then
    return { r = "eq" }
  end
  if f ~= 3 then
    return { r = "ne" }
  end
  return { r = "unreachable" }
end

function precedence(context)
  if context.a or context.b and context.c then
    return { r = "yes" }
  end
  return { r = "no" }
end

function parentheses(context)
  if (context.a or context.b) and context.c then
    return { r = "yes" }
  end
  return { r = "no" }
end

function not_binds_tight(context)
  if not context.a and context.b then
    return { r = "b_only" }
  end
  return { r = "other" }
end

function compare_numbers(context)
  local n = context.n or 0
  if n >= 5 and n < 10 then
    return { r = "mid" }
  end
  if n > 10 then
    return { r = "high" }
  end
  return { r = "low" }
end

function compare_strings(context)
  if context.name == "lily" then
    return { r = "is_lily" }
  end
  if context.name ~= "lily" and context.name == "oak" then
    return { r = "is_oak" }
  end
  return { r = "other" }
end

function concat_in_log(context)
  api.set_flag("logged", true)
  api.log("hello " .. "world " .. id)
  return { ok = true }
end

function flag_value(context)
  return api.get_flag("seen")
end

function flag_as_bare_identifier(context)
  if seen and not gone then
    return { r = "seen_not_gone" }
  end
  return { r = "no" }
end

function side_effects_in_order(context)
  api.set_flag("a", true)
  if context.stop then
    return { r = "stopped" }
  end
  api.set_flag("b", true)
  return { r = "done" }
end
