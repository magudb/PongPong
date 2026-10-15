-- V7: Danish-first draft copy. Voice keys are hooks, not recordings.
kind = "dialogue"
id = "carpenter_brumme"

function get_dialogue(context)
  if context.quest_active_fix_roof then
    return {
      speaker = "carpenter_brumme",
      speaker_name_key = "NPC_CARPENTER_BRUMME",
      lines = {
        {
          id = "greet",
          text_key = "DLG_BRUMME_GREET",
          voice_key = "voice/carpenter_brumme/greet",
        },
        {
          id = "roof",
          text_key = "DLG_BRUMME_ROOF",
          voice_key = "voice/carpenter_brumme/roof",
        },
        {
          id = "help",
          text_key = "DLG_BRUMME_HELP",
          voice_key = "voice/carpenter_brumme/help",
        },
      },
      choices = {
        {
          id = "shop",
          text_key = "DLG_BRUMME_CHOICE_SHOP",
          action = "open_shop",
          shop_id = "timber_yard",
        },
        {
          id = "goodbye",
          text_key = "DLG_BRUMME_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if context.brumme_at_stall then
    return {
      speaker = "carpenter_brumme",
      speaker_name_key = "NPC_CARPENTER_BRUMME",
      lines = {
        {
          id = "market",
          text_key = "DLG_BRUMME_MARKET",
          voice_key = "voice/carpenter_brumme/market",
        },
        {
          id = "timber",
          text_key = "DLG_BRUMME_TIMBER",
          voice_key = "voice/carpenter_brumme/timber",
        },
        {
          id = "tools",
          text_key = "DLG_BRUMME_TOOLS",
          voice_key = "voice/carpenter_brumme/tools",
        },
      },
      choices = {
        {
          id = "shop",
          text_key = "DLG_BRUMME_CHOICE_SHOP",
          action = "open_shop",
          shop_id = "timber_yard",
        },
        {
          id = "goodbye",
          text_key = "DLG_BRUMME_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  return {
    speaker = "carpenter_brumme",
    speaker_name_key = "NPC_CARPENTER_BRUMME",
    lines = {
      {
        id = "greet",
        text_key = "DLG_BRUMME_GREET",
        voice_key = "voice/carpenter_brumme/greet",
      },
      {
        id = "slow",
        text_key = "DLG_BRUMME_SLOW",
        voice_key = "voice/carpenter_brumme/slow",
      },
      {
        id = "rest",
        text_key = "DLG_BRUMME_REST",
        voice_key = "voice/carpenter_brumme/rest",
      },
    },
    choices = {
      {
        id = "shop",
        text_key = "DLG_BRUMME_CHOICE_SHOP",
        action = "open_shop",
        shop_id = "timber_yard",
      },
      {
        id = "goodbye",
        text_key = "DLG_BRUMME_CHOICE_GOODBYE",
        action = "close",
      },
    },
  }
end
