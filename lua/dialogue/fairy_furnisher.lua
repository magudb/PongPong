-- dialogue/fairy_furnisher.lua
-- Shopkeeper fairy: greets and opens furniture_shop.

kind = "dialogue"
id = "fairy_furnisher"

function get_dialogue(context)
  return {
    speaker = "fairy_furnisher",
    speaker_name_key = "NPC_FAIRY_FURNISHER",
    lines = {
      {
        id = "greet",
        text_key = "DLG_FURNISHER_GREET",
        voice_key = "voice/fairy_furnisher/greet",
      },
    },
    choices = {
      {
        id = "open_shop",
        text_key = "DIALOGUE_CHOICE_OPEN_SHOP",
        action = "open_shop",
        shop_id = "furniture_shop",
      },
      {
        id = "goodbye",
        text_key = "DIALOGUE_CHOICE_GOODBYE",
        action = "close",
      },
    },
  }
end
