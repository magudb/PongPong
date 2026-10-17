-- Manual evidence is projected from the permanent MotherStory record.
kind = "quest"
id = "forest_mother_s07"
title_key = "FM_CHAPTER_S07_TITLE"
description_key = "FM_CHAPTER_S07_DESC"
objectives = {
  { id = "last_journey", on = "manual", target = 1, description_key = "FM_E_LAST_JOURNEY_TITLE" },
  { id = "checkpoint", on = "manual", target = 1, description_key = "FM_OBJ_CHECKPOINT_S07" },
}
rewards = {}
meta = { giver = "postman_pip", location = "ZONE_DARK_FOREST", tag = "SKOV", category = "adventure", repeatable = false }
function is_available(context)
  return api.has_flag("forest_mother_ready_s07")
end
