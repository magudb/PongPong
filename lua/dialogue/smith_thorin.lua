-- dialogue/smith_thorin.lua
-- Dwarven smith Thorin — gruff but kind, loves rare metals.

kind = "dialogue"
id = "smith_thorin"

function get_dialogue(context)
  return {
    speaker = "smith_thorin",
    speaker_name_key = "NPC_SMITH_THORIN",
    lines = {
      {
        id = "greet",
        text_key = "DLG_THORIN_GREET",
        voice_key = "voice/smith_thorin/greet",
      },
      {
        id = "mining_talk",
        text_key = "DLG_THORIN_MINING_TALK",
        voice_key = "voice/smith_thorin/mining_talk",
      },
    },
    choices = {
      {
        id = "mining_quest",
        text_key = "DLG_CHOICE_MINING_QUEST",
        action = "quest_accept",
        quest_id = "dark_forest_mining",
      },
      {
        id = "open_shop",
        text_key = "DLG_CHOICE_OPEN_SHOP",
        action = "open_shop",
        shop_id = "smithy",
      },
      {
        id = "goodbye",
        text_key = "DLG_CHOICE_GOODBYE",
        action = "close",
      },
    },
  }
end
