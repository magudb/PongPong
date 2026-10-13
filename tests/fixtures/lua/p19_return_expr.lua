kind = "quest"
id = "p19"
function is_available(context)
  return api.has_item("cookie", 3) and not api.has_flag("done")
end
