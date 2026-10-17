-- Manual evidence is projected from the permanent MotherStory record.
kind = "quest"
id = "forest_mother_s08"
title_key = "FM_CHAPTER_S08_TITLE"
description_key = "FM_CHAPTER_S08_DESC"
objectives = {
  { id = "mother_fate", on = "manual", target = 1, description_key = "FM_E_MOTHER_FATE_TITLE" },
  { id = "legacy_home", on = "manual", target = 1, description_key = "FM_E_LEGACY_HOME_TITLE" },
}
rewards = {}
meta = { giver = "postman_pip", location = "ZONE_DARK_FOREST", tag = "SKOV", category = "adventure", repeatable = false }
function is_available(context)
  return api.has_flag("forest_mother_ready_s08")
end
