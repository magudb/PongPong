-- Manual evidence is projected from the permanent MotherStory record.
kind = "quest"
id = "forest_mother_s05"
title_key = "FM_CHAPTER_S05_TITLE"
description_key = "FM_CHAPTER_S05_DESC"
objectives = {
  { id = "traveller_account", on = "manual", target = 1, description_key = "FM_E_TRAVELLER_ACCOUNT_TITLE" },
  { id = "checkpoint", on = "manual", target = 1, description_key = "FM_OBJ_CHECKPOINT_S05" },
}
rewards = {}
meta = { giver = "postman_pip", location = "ZONE_DARK_FOREST", tag = "SKOV", category = "adventure", repeatable = false }
function is_available(context)
  return api.has_flag("forest_mother_ready_s05")
end
