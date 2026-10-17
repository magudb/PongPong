-- Manual evidence is projected from the permanent MotherStory record.
kind = "quest"
id = "forest_mother_s04"
title_key = "FM_CHAPTER_S04_TITLE"
description_key = "FM_CHAPTER_S04_DESC"
objectives = {
  { id = "memory_lamp", on = "manual", target = 1, description_key = "FM_E_MEMORY_LAMP_TITLE" },
  { id = "memory_table", on = "manual", target = 1, description_key = "FM_E_MEMORY_TABLE_TITLE" },
  { id = "memory_basket", on = "manual", target = 1, description_key = "FM_E_MEMORY_BASKET_TITLE" },
  { id = "memory_map", on = "manual", target = 1, description_key = "FM_E_MEMORY_MAP_TITLE" },
  { id = "echo_account", on = "manual", target = 1, description_key = "FM_E_ECHO_ACCOUNT_TITLE" },
}
rewards = {}
meta = { source_key = "FM_INVESTIGATION", location = "ZONE_DARK_FOREST", tag = "SKOV", category = "adventure", repeatable = false }
function is_available(context)
  return api.has_flag("forest_mother_ready_s04")
end
