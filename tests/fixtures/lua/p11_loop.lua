kind = "quest"
id = "p11"
function on_accept(context)
  for i = 1, 3 do
    api.add_gold(10)
  end
  return { ok = true }
end
