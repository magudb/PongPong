kind = "quest"
id = "p21"
function on_accept(context)
  api.notification(
    "Title",
    "Message"
  )
  api.set_flag("after_ml", true)
  return { ok = true }
end
