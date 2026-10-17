-- Manual evidence is projected from the permanent MotherStory record.
kind = "quest"
id = "forest_mother_s06"
title_key = "FM_CHAPTER_S06_TITLE"
description_key = "FM_CHAPTER_S06_DESC"
objectives = {
  { id = "return_promise", on = "manual", target = 1, description_key = "FM_E_RETURN_PROMISE_TITLE" },
  { id = "route_stone", on = "manual", target = 1, description_key = "FM_E_ROUTE_STONE_TITLE" },
  { id = "route_witness", on = "manual", target = 1, description_key = "FM_E_ROUTE_WITNESS_TITLE" },
}
rewards = {}
meta = { giver = "postman_pip", location = "ZONE_DARK_FOREST", tag = "SKOV", category = "adventure", repeatable = false }
function is_available(context)
  return api.has_flag("forest_mother_ready_s06")
end
