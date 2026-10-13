kind = "dialogue"
id = "p16"
function get_dialogue(context)
  local items = { "a", "b", "c" }
  return { count = #items, s = string.format("%d gold", 5), up = string.upper("abc") }
end
