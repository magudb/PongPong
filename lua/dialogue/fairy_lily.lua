-- dialogue/fairy_lily.lua
-- Fairy child Lily — worried about her lost cat.

kind = "dialogue"
id = "fairy_lily"

function get_dialogue(context)
  local lost_cat_active = context.lost_cat_active or false
  if lost_cat_active then
    return {
      speaker = "fairy_lily",
      speaker_name_key = "NPC_FAIRY_LILY",
      lines = {
        {
          id = "worried",
          text_key = "DIALOGUE_LILY_WORRIED",
          voice_key = "voice/lily/worried",
        },
      },
      choices = {
        {
          id = "keep_searching",
          text_key = "DIALOGUE_CHOICE_KEEP_SEARCHING",
          action = "close",
        },
      },
    }
  end

  return {
    speaker = "fairy_lily",
    speaker_name_key = "NPC_FAIRY_LILY",
    lines = {
      {
        id = "greet",
        text_key = "DIALOGUE_LILY_GREET",
        voice_key = "voice/lily/greet",
      },
      {
        id = "cat_missing",
        text_key = "DIALOGUE_LILY_CAT_MISSING",
        voice_key = "voice/lily/cat_missing",
      },
    },
    choices = {
      {
        id = "help_find_cat",
        text_key = "DIALOGUE_CHOICE_HELP_FIND_CAT",
        action = "quest_accept",
        quest_id = "lost_cat",
      },
      {
        id = "goodbye",
        text_key = "DIALOGUE_CHOICE_GOODBYE",
        action = "close",
      },
    },
  }
end
