-- V7: Danish-first draft copy. Voice keys are hooks, not recordings.
kind = "dialogue"
id = "beekeeper_birk"

function get_dialogue(context)
  if context.race == "fairy" then
    return {
      speaker = "beekeeper_birk",
      speaker_name_key = "NPC_BEEKEEPER_BIRK",
      lines = {
        {
          id = "greet",
          text_key = "DLG_BIRK_GREET",
          voice_key = "voice/beekeeper_birk/greet",
        },
        {
          id = "family",
          text_key = "DLG_BIRK_FAMILY",
          voice_key = "voice/beekeeper_birk/family",
        },
        {
          id = "wings",
          text_key = "DLG_BIRK_WINGS",
          voice_key = "voice/beekeeper_birk/wings",
        },
        {
          id = "flowers",
          text_key = "DLG_BIRK_FLOWERS",
          voice_key = "voice/beekeeper_birk/flowers",
        },
      },
      choices = {
        {
          id = "goodbye",
          text_key = "DLG_BIRK_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  return {
    speaker = "beekeeper_birk",
    speaker_name_key = "NPC_BEEKEEPER_BIRK",
    lines = {
      {
        id = "greet",
        text_key = "DLG_BIRK_GREET",
        voice_key = "voice/beekeeper_birk/greet",
      },
      {
        id = "bees",
        text_key = "DLG_BIRK_BEES",
        voice_key = "voice/beekeeper_birk/bees",
      },
      {
        id = "honey",
        text_key = "DLG_BIRK_HONEY",
        voice_key = "voice/beekeeper_birk/honey",
      },
      {
        id = "quiet",
        text_key = "DLG_BIRK_QUIET",
        voice_key = "voice/beekeeper_birk/quiet",
      },
      {
        id = "farewell",
        text_key = "DLG_BIRK_FAREWELL",
        voice_key = "voice/beekeeper_birk/farewell",
      },
    },
    choices = {
      {
        id = "goodbye",
        text_key = "DLG_BIRK_CHOICE_GOODBYE",
        action = "close",
      },
    },
  }
end
