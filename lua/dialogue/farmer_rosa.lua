-- dialogue/farmer_rosa.lua
-- Farmer Rosa — runs the cute farm animal store. Loves all creatures.

kind = "dialogue"
id = "farmer_rosa"

function get_dialogue(context)
  return {
    speaker = "farmer_rosa",
    speaker_name_key = "NPC_FARMER_ROSA",
    lines = {
      {
        id = "greet",
        text_key = "DIALOGUE_ROSA_GREET",
        voice_key = "voice/rosa/greet",
      },
      {
        id = "animal_talk",
        text_key = "DIALOGUE_ROSA_ANIMAL_TALK",
        voice_key = "voice/rosa/animal_talk",
      },
    },
    choices = {
      {
        id = "open_shop",
        text_key = "DIALOGUE_CHOICE_OPEN_SHOP",
        action = "open_shop",
        shop_id = "animal_store",
      },
      {
        id = "math_harvest",
        text_key = "DIALOGUE_CHOICE_MATH_HARVEST",
        action = "quest_accept",
        quest_id = "math_harvest_puzzle",
      },
      {
        id = "about_animals",
        text_key = "DIALOGUE_CHOICE_ABOUT_ANIMALS",
        action = "show_info",
        info_key = "INFO_ANIMALS",
      },
      {
        id = "goodbye",
        text_key = "DIALOGUE_CHOICE_GOODBYE",
        action = "close",
      },
    },
  }
end
