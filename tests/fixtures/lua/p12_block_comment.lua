kind = "quest"
id = "p12"
--[[ block comment
function on_accept(context)
  api.set_flag("from_comment", true)
end
]]
function on_accept(context)
  api.set_flag("real", true)
  return { ok = true }
end
