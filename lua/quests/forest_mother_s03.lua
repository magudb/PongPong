-- Manual evidence is projected from the permanent MotherStory record.
kind = "quest"
id = "forest_mother_s03"
title_key = "FM_CHAPTER_S03_TITLE"
description_key = "FM_CHAPTER_S03_DESC"
objectives = {
  { id = "marked_lamp", on = "manual", target = 1, description_key = "FM_E_MARKED_LAMP_TITLE" },
  { id = "map_account", on = "manual", target = 1, description_key = "FM_E_MAP_ACCOUNT_TITLE" },
  { id = "checkpoint", on = "manual", target = 1, description_key = "FM_OBJ_CHECKPOINT_S03" },
}
rewards = {}
meta = { giver = "postman_pip", location = "ZONE_DARK_FOREST", tag = "SKOV", category = "adventure", repeatable = false }
function is_available(context)
  return api.has_flag("forest_mother_ready_s03")
end
