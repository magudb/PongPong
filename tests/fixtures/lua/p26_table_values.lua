-- tests/fixtures/lua/p26_table_values.lua
-- A table built inside a function evaluates its values (LUA-08): one page with a greeting picked by if / elseif / else and a
-- shared choice table, instead of one copied page per variant. An absent value (nil) leaves its key out.
kind = "dialogue"
id = "p26"

function get_dialogue(context)
  local greet = "DLG_P26_DAY"
  if context.morning then
    greet = "DLG_P26_MORNING"
  elseif context.evening then
    greet = "DLG_P26_EVENING"
  else
    api.set_flag("p26_daytime", true)
  end
  local bye = { text_key = "DLG_P26_BYE", action = "close" }
  return {
    lines = { { speaker = "p26", text_key = greet, mood = context.mood } },
    choices = { { text_key = "DLG_P26_SHOP", shop_id = context.shop or "seed_shop" }, bye },
    ["seen"] = api.has_flag("p26_seen"),
  }
end
