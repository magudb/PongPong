kind = "dialogue"
id = "cat_morfar_mis"
function get_dialogue(context)
  if context.zone == "dark_forest" then
    return {
      speaker = "cat_morfar_mis", speaker_name_key = "NPC_CAT_MORFAR_MIS",
      lines = { { id = "forest", text_key = "DLG_MIS_FOREST", voice_key = "voice/cat_morfar_mis/forest" } },
      choices = { { id = "bye", text_key = "DLG_CHOICE_GOODBYE", action = "close" } },
    }
  end
  return {
    speaker = "cat_morfar_mis", speaker_name_key = "NPC_CAT_MORFAR_MIS",
    lines = { { id = "home", text_key = "DLG_MIS_HOME", voice_key = "voice/cat_morfar_mis/home" } },
    choices = { { id = "bye", text_key = "DLG_CHOICE_GOODBYE", action = "close" } },
  }
end
