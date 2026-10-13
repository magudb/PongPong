-- dialogue/guard_oak.lua
-- Guard Oak — protects the forest edge, tough but fair.

kind = "dialogue"
id = "guard_oak"

function get_dialogue(context)
  return {
    speaker = "guard_oak",
    speaker_name_key = "NPC_GUARD_OAK",
    lines = {
      {
        id = "greet",
        text_key = "DIALOGUE_OAK_GREET",
        voice_key = "voice/oak/greet",
      },
    },
    choices = {
      {
        id = "patrol_quest",
        text_key = "DIALOGUE_CHOICE_MINING_QUEST",
        action = "quest_accept",
        quest_id = "forest_patrol",
      },
      {
        id = "goodbye",
        text_key = "DIALOGUE_CHOICE_GOODBYE",
        action = "close",
      },
    },
  }
end
