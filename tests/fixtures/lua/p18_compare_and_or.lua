kind = "dialogue"
id = "p18"
function get_dialogue(context)
  if context.a and context.b or context.c then
    return { r = "yes" }
  end
  return { r = "no" }
end
