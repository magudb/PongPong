-- V7: Danish-first draft copy. Voice keys are hooks, not recordings.
kind = "dialogue"
id = "bathkeeper_sofus"

function get_dialogue(context)
  if context.bath_day == context.total_day then
    return {
      speaker = "bathkeeper_sofus",
      speaker_name_key = "NPC_BATHKEEPER_SOFUS",
      lines = {
        {
          id = "greet",
          text_key = "DLG_SOFUS_GREET",
          voice_key = "voice/bathkeeper_sofus/greet",
        },
        {
          id = "once",
          text_key = "DLG_SOFUS_ONCE",
          voice_key = "voice/bathkeeper_sofus/once",
        },
        {
          id = "orange",
          text_key = "DLG_SOFUS_ORANGE",
          voice_key = "voice/bathkeeper_sofus/orange",
        },
      },
      choices = {
        {
          id = "goodbye",
          text_key = "DLG_SOFUS_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if context.stamina_ratio and context.stamina_ratio < 0.3 then
    return {
      speaker = "bathkeeper_sofus",
      speaker_name_key = "NPC_BATHKEEPER_SOFUS",
      lines = {
        {
          id = "tired",
          text_key = "DLG_SOFUS_TIRED",
          voice_key = "voice/bathkeeper_sofus/tired",
        },
        {
          id = "towel",
          text_key = "DLG_SOFUS_TOWEL",
          voice_key = "voice/bathkeeper_sofus/towel",
        },
        {
          id = "offer",
          text_key = "DLG_SOFUS_OFFER",
          voice_key = "voice/bathkeeper_sofus/offer",
        },
      },
      choices = {
        {
          id = "bath",
          text_key = "DLG_SOFUS_CHOICE_BATH",
          action = "emit_event",
          event = "bath_request",
          npc = "bathkeeper_sofus",
        },
        {
          id = "goodbye",
          text_key = "DLG_SOFUS_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if context.hour and context.hour >= 18 then
    return {
      speaker = "bathkeeper_sofus",
      speaker_name_key = "NPC_BATHKEEPER_SOFUS",
      lines = {
        {
          id = "evening",
          text_key = "DLG_SOFUS_EVENING",
          voice_key = "voice/bathkeeper_sofus/evening",
        },
        {
          id = "steam",
          text_key = "DLG_SOFUS_STEAM",
          voice_key = "voice/bathkeeper_sofus/steam",
        },
        {
          id = "offer",
          text_key = "DLG_SOFUS_OFFER",
          voice_key = "voice/bathkeeper_sofus/offer",
        },
      },
      choices = {
        {
          id = "bath",
          text_key = "DLG_SOFUS_CHOICE_BATH",
          action = "emit_event",
          event = "bath_request",
          npc = "bathkeeper_sofus",
        },
        {
          id = "goodbye",
          text_key = "DLG_SOFUS_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  return {
    speaker = "bathkeeper_sofus",
    speaker_name_key = "NPC_BATHKEEPER_SOFUS",
    lines = {
      {
        id = "greet",
        text_key = "DLG_SOFUS_GREET",
        voice_key = "voice/bathkeeper_sofus/greet",
      },
      {
        id = "orange",
        text_key = "DLG_SOFUS_ORANGE",
        voice_key = "voice/bathkeeper_sofus/orange",
      },
      {
        id = "offer",
        text_key = "DLG_SOFUS_OFFER",
        voice_key = "voice/bathkeeper_sofus/offer",
      },
    },
    choices = {
      {
        id = "bath",
        text_key = "DLG_SOFUS_CHOICE_BATH",
        action = "emit_event",
        event = "bath_request",
        npc = "bathkeeper_sofus",
      },
      {
        id = "goodbye",
        text_key = "DLG_SOFUS_CHOICE_GOODBYE",
        action = "close",
      },
    },
  }
end
