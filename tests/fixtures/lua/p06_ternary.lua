kind = "dialogue"
id = "p06"
function get_dialogue(context)
  local v = context.x and "yes" or "no"
  return { r = v }
end
