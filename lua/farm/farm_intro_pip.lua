-- farm/farm_intro_pip.lua (package N04): Pip's greeting at the mailbox, the first thing a new player hears.
kind = "dialogue"
id = "farm_intro_pip"

function get_dialogue(context)
  return {
    social = false,
    speaker = "postman_pip",
    speaker_name_key = "NPC_POSTMAN_PIP",
    lines = {
      { id = "greet_1", text_key = "DLG_FARMINTRO_PIP_1" },
      { id = "greet_2", text_key = "DLG_FARMINTRO_PIP_2" },
      { id = "greet_3", text_key = "DLG_FARMINTRO_PIP_3" },
    },
    choices = {
      { id = "thanks", text_key = "DLG_FARMINTRO_CHOICE_THANKS", action = "close" },
    },
  }
end
