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
        text_key = "DLG_MERCHANT_GREET",
        voice_key = "voice/pip/greet",
      },
    },
    choices = {
      {
        id = "open_shop",
        text_key = "DLG_CHOICE_OPEN_SHOP",
        action = "open_shop",
        shop_id = "seed_shop",
      },
      {
        id = "goodbye",
        text_key = "DLG_CHOICE_GOODBYE",
        action = "close",
      },
    },
  }
end
