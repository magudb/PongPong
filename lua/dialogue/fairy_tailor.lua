-- dialogue/fairy_tailor.lua
-- Shopkeeper fairy: greets and opens tailor_shop.

kind = "dialogue"
id = "fairy_tailor"

function get_dialogue(context)
  return {
    speaker = "fairy_tailor",
    speaker_name_key = "NPC_FAIRY_TAILOR",
    lines = {
      {
        id = "greet",
        text_key = "DLG_TAILOR_GREET",
        voice_key = "voice/fairy_tailor/greet",
      },
    },
    choices = {
      {
        id = "open_shop",
        text_key = "DIALOGUE_CHOICE_OPEN_SHOP",
        action = "open_shop",
        shop_id = "tailor_shop",
      },
      {
        id = "goodbye",
        text_key = "DIALOGUE_CHOICE_GOODBYE",
        action = "close",
      },
    },
  }
end
