kind = "dialogue"
id = "p05"
function get_dialogue(context)
  if context.x then return { r = "x" } end
  return { r = "none" }
end
