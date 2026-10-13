kind = "dialogue"
id = "p13"
local function pick(x)
  return x
end
function get_dialogue(context)
  return { r = pick("hello") }
end
