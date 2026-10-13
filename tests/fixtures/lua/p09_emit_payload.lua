kind = "quest"
id = "p09"
function on_accept(context)
  api.emit("quest_update", { quest_id = "math_harvest_puzzle", objective_id = "harvest_carrot", amount = 3 })
  return { ok = true }
end
