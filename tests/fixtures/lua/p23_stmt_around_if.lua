kind = "quest"
id = "p23"
function on_accept(context)
  api.set_flag("before_if", true)
  if context.x then
    api.set_flag("in_if", true)
  end
  api.set_flag("after_if", true)
  return { ok = true }
end
