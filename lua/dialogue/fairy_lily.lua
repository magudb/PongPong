kind = "dialogue"
id = "fairy_lily"
function get_dialogue(context)
  return {
    speaker = "fairy_lily", speaker_name_key = "NPC_FAIRY_LILY",
    lines = { { id = "greet", text_key = "DLG_LILY_GREET", voice_key = "voice/fairy_lily/greet" } },
    choices = { { id = "bye", text_key = "DLG_CHOICE_GOODBYE", action = "close" } },
  }
end
