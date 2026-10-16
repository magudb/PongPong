-- farm/farm_intro_pip_bye.lua (package N04): Pip's goodbye after the letter; the first two instructions of the game.
kind = "dialogue"
id = "farm_intro_pip_bye"

function get_dialogue(context)
  return {
    social = false,
    speaker = "postman_pip",
    speaker_name_key = "NPC_POSTMAN_PIP",
    lines = {
      { id = "bye_1", text_key = "DLG_FARMINTRO_PIP_BYE_1", format_actions = { "slot_1", "use_tool" }, format_action_groups_gamepad = { { "hotbar_previous", "hotbar_next" }, { "use_tool" } } },
      { id = "bye_2", text_key = "DLG_FARMINTRO_PIP_BYE_2" },
    },
    choices = {
      { id = "goodbye", text_key = "DLG_FARMINTRO_CHOICE_BYE", action = "close" },
    },
  }
end
