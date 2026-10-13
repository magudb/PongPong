-- tests/fixtures/lua/lint_clean_sample.lua
-- Everything the supported subset offers in one quest file: it must lint clean and run (data.lint_clean).

kind = "quest"
id = "lint_clean_sample"

objectives = {
  { id = "first", target = 3, on = "item_gained", item = "carrot", have = true, description = "Collect carrots" },
  { id = "second", target = 1, on = "dialogue_started", any_of = { "baker_maja", "mayor_lyra" }, after_others = true },
}

rewards = {
  gold = 150,
  items = { catnip_seeds = 3 },
  friendship = { pippin_boegeknop = 1 },
}

meta = { giver = "pippin_boegeknop", tag = "FIND", repeatable = false, cooldown_days = 0, offset = -2, ratio = 0.5 }

function on_accept(context)
  local seen = context.seen or false
  local count = context.count or 0
  api.log("accepted " .. id)
  api.set_flag("fixture_started", true)
  if seen and count >= 2 then
    if not api.has_flag("fixture_done") then
      api.add_gold(5)
    end
    return { ok = true, nested = { list = { 1, 2 }, flag = false } }
  end
  if context.never then return { ok = false } end
  return { ok = true }
end

function is_available(context)
  return not api.has_flag("fixture_done") and (api.get_gold() >= 0 or context.free)
end
