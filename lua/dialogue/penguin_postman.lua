kind = "dialogue"
id = "penguin_postman"
function get_dialogue(context)
  return {
    speaker = "penguin_postman", speaker_name_key = "NPC_PENGUIN_POSTMAN",
    lines = { { id = "hello", text_key = "DLG_PENGUIN_HELLO", voice_key = "voice/penguin_postman/hello" } },
    choices = { { id = "bye", text_key = "DLG_CHOICE_GOODBYE", action = "close" } },
  }
end
