kind = "quest"
id = "p08"
function on_accept(context)
  api.notification("Hej (test)", "Msg")
  api.set_flag("after_paren", true)
  return { ok = true }
end
