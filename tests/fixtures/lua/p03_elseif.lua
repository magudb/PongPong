kind = "dialogue"
id = "p03"
function get_dialogue(context)
  if context.x then
    return { r = "x" }
  elseif context.y then
    return { r = "y" }
  end
  return { r = "none" }
end
