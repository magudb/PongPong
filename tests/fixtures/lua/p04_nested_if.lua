kind = "dialogue"
id = "p04"
function get_dialogue(context)
  if context.a then
    if context.b then
      return { r = "ab" }
    end
    return { r = "a_only" }
  end
  return { r = "none" }
end
