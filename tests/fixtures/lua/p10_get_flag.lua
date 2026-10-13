kind = "dialogue"
id = "p10"
function get_dialogue(context)
  local v = api.get_flag("seen")
  return { r = v }
end
