kind = "dialogue"
id = "p02"
function get_dialogue(context)
  if context.x then
    return { r = "then" }
  else
    return { r = "else" }
  end
end
