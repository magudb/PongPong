-- dialogue/merchant_pip.lua
-- Merchant Pip — runs the general store, cheerful and helpful.

kind = "dialogue"
id = "merchant_pip"

function get_dialogue(context)
  return {
    speaker = "merchant_pip",
    speaker_name_key = "NPC_MERCHANT_PIP",
    lines = {
      {
        id = "greet",
        text_key = "DIALOGUE_PIP_GREET",
        voice_key = "voice/pip/greet",
      },
    },
    choices = {
      {
        id = "open_shop",
        text_key = "DIALOGUE_CHOICE_OPEN_SHOP",
        action = "open_shop",
        shop_id = "general_store",
      },
      {
        id = "goodbye",
        text_key = "DIALOGUE_CHOICE_GOODBYE",
        action = "close",
      },
    },
  }
end
