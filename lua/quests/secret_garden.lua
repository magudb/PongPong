-- The communal garden and the first confirmed trail to our mother.
-- SecretGardenStory owns these manual completions, preserving their order.
kind = "quest"
id = "secret_garden"
objectives = {
  { id = "clear_path", on = "manual", target = 1, description_key = "OBJ_SECRET_GARDEN_CLEAR_PATH" },
  { id = "ask_hoppe", on = "manual", target = 1, description_key = "OBJ_SECRET_GARDEN_ASK_HOPPE" },
  { id = "ask_brumme", on = "manual", target = 1, description_key = "OBJ_SECRET_GARDEN_ASK_BRUMME" },
  { id = "restore_bench", on = "manual", target = 1, description_key = "OBJ_SECRET_GARDEN_RESTORE_BENCH" },
  { id = "plant_beds", on = "manual", target = 1, description_key = "OBJ_SECRET_GARDEN_PLANT_BEDS" },
  { id = "water_beds", on = "manual", target = 1, description_key = "OBJ_SECRET_GARDEN_WATER_BEDS" },
  { id = "see_blossoms", on = "manual", target = 1, description_key = "OBJ_SECRET_GARDEN_SEE_BLOSSOMS" },
  { id = "read_letter", on = "manual", target = 1, description_key = "OBJ_SECRET_GARDEN_READ_LETTER" },
  { id = "ask_pip", on = "manual", target = 1, description_key = "OBJ_SECRET_GARDEN_ASK_PIP" },
  { id = "ask_oak", on = "manual", target = 1, description_key = "OBJ_SECRET_GARDEN_ASK_OAK" },
  { id = "follow_trace", on = "manual", target = 1, description_key = "OBJ_SECRET_GARDEN_FOLLOW_TRACE" },
  { id = "homecoming", on = "manual", target = 1, description_key = "OBJ_SECRET_GARDEN_HOMECOMING" },
}
rewards = { gold = 150, friendship = { gardener_hoppe = 1, carpenter_brumme = 1 } }
meta = { giver = "gardener_hoppe", location = "ZONE_CITY", tag = "FIND", category = "help", repeatable = false }
function on_offer(context)
  return { available = true, text_key = "QUEST_SECRET_GARDEN_OFFER" }
end
function is_available(context)
  return not api.has_flag("intro_pending")
end
