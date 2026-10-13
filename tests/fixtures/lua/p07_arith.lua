kind = "dialogue"
id = "p07"
function get_dialogue(context)
  local n = 3 * 4
  return { r = n, s = context.base + 1 }
end
