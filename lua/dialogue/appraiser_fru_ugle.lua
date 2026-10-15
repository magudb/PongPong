-- V7: Danish-first draft copy. Voice keys are hooks, not recordings.
kind = "dialogue"
id = "appraiser_fru_ugle"

function get_dialogue(context)
  if context.quest_offer_ugles_noegle and context.quest_offer_rune_vandring then
    return {
      speaker = "appraiser_fru_ugle",
      speaker_name_key = "NPC_APPRAISER_FRU_UGLE",
      lines = {
        {
          id = "greet",
          text_key = "DLG_UGLE_GREET",
          voice_key = "voice/appraiser_fru_ugle/greet",
        },
        {
          id = "lake",
          text_key = "DLG_UGLE_LAKE",
          voice_key = "voice/appraiser_fru_ugle/lake",
        },
        {
          id = "runes",
          text_key = "DLG_UGLE_RUNES",
          voice_key = "voice/appraiser_fru_ugle/runes",
        },
      },
      choices = {
        {
          id = "appraise",
          text_key = "DLG_UGLE_CHOICE_APPRAISE",
          action = "emit_event",
          event = "open_appraisal",
          npc = "appraiser_fru_ugle",
        },
        {
          id = "key",
          text_key = "DLG_UGLE_CHOICE_KEY",
          action = "quest_accept",
          quest_id = "ugles_noegle",
        },
        {
          id = "runes",
          text_key = "DLG_UGLE_CHOICE_RUNES",
          action = "quest_accept",
          quest_id = "rune_vandring",
        },
        {
          id = "goodbye",
          text_key = "DLG_UGLE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if context.quest_offer_ugles_noegle then
    return {
      speaker = "appraiser_fru_ugle",
      speaker_name_key = "NPC_APPRAISER_FRU_UGLE",
      lines = {
        {
          id = "greet",
          text_key = "DLG_UGLE_GREET",
          voice_key = "voice/appraiser_fru_ugle/greet",
        },
        {
          id = "lake",
          text_key = "DLG_UGLE_LAKE",
          voice_key = "voice/appraiser_fru_ugle/lake",
        },
        {
          id = "glass",
          text_key = "DLG_UGLE_GLASS",
          voice_key = "voice/appraiser_fru_ugle/glass",
        },
      },
      choices = {
        {
          id = "appraise",
          text_key = "DLG_UGLE_CHOICE_APPRAISE",
          action = "emit_event",
          event = "open_appraisal",
          npc = "appraiser_fru_ugle",
        },
        {
          id = "key",
          text_key = "DLG_UGLE_CHOICE_KEY",
          action = "quest_accept",
          quest_id = "ugles_noegle",
        },
        {
          id = "goodbye",
          text_key = "DLG_UGLE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if context.quest_offer_rune_vandring then
    return {
      speaker = "appraiser_fru_ugle",
      speaker_name_key = "NPC_APPRAISER_FRU_UGLE",
      lines = {
        {
          id = "greet",
          text_key = "DLG_UGLE_GREET",
          voice_key = "voice/appraiser_fru_ugle/greet",
        },
        {
          id = "runes",
          text_key = "DLG_UGLE_RUNES",
          voice_key = "voice/appraiser_fru_ugle/runes",
        },
        {
          id = "patience",
          text_key = "DLG_UGLE_PATIENCE",
          voice_key = "voice/appraiser_fru_ugle/patience",
        },
      },
      choices = {
        {
          id = "appraise",
          text_key = "DLG_UGLE_CHOICE_APPRAISE",
          action = "emit_event",
          event = "open_appraisal",
          npc = "appraiser_fru_ugle",
        },
        {
          id = "runes",
          text_key = "DLG_UGLE_CHOICE_RUNES",
          action = "quest_accept",
          quest_id = "rune_vandring",
        },
        {
          id = "goodbye",
          text_key = "DLG_UGLE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  return {
    speaker = "appraiser_fru_ugle",
    speaker_name_key = "NPC_APPRAISER_FRU_UGLE",
    lines = {
      {
        id = "greet",
        text_key = "DLG_UGLE_GREET",
        voice_key = "voice/appraiser_fru_ugle/greet",
      },
      {
        id = "finds",
        text_key = "DLG_UGLE_FINDS",
        voice_key = "voice/appraiser_fru_ugle/finds",
      },
      {
        id = "window",
        text_key = "DLG_UGLE_WINDOW",
        voice_key = "voice/appraiser_fru_ugle/window",
      },
      {
        id = "farewell",
        text_key = "DLG_UGLE_FAREWELL",
        voice_key = "voice/appraiser_fru_ugle/farewell",
      },
    },
    choices = {
      {
        id = "appraise",
        text_key = "DLG_UGLE_CHOICE_APPRAISE",
        action = "emit_event",
        event = "open_appraisal",
        npc = "appraiser_fru_ugle",
      },
      {
        id = "goodbye",
        text_key = "DLG_UGLE_CHOICE_GOODBYE",
        action = "close",
      },
    },
  }
end
