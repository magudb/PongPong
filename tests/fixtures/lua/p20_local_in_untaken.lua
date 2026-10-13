kind = "dialogue"
id = "p20"
function get_dialogue(context)
  if context.never then
    local z = api.get_gold()
    return { r = "never" }
  end
  return { r = "ok" }
end
