-- V7: Danish-first draft copy. Voice keys are hooks, not recordings.
kind = "dialogue"
id = "mapseller_natteblik"

function get_dialogue(context)
  if context.shop_natteblik_maps and context.hour and context.hour >= 21 then
    return {
      speaker = "mapseller_natteblik",
      speaker_name_key = "NPC_MAPSELLER_NATTEBLIK",
      lines = {
        {
          id = "night",
          text_key = "DLG_NATTEBLIK_NIGHT",
          voice_key = "voice/mapseller_natteblik/night",
        },
        {
          id = "roots",
          text_key = "DLG_NATTEBLIK_ROOTS",
          voice_key = "voice/mapseller_natteblik/roots",
        },
        {
          id = "maps",
          text_key = "DLG_NATTEBLIK_MAPS",
          voice_key = "voice/mapseller_natteblik/maps",
        },
        {
          id = "lantern",
          text_key = "DLG_NATTEBLIK_LANTERN",
          voice_key = "voice/mapseller_natteblik/lantern",
        },
      },
      choices = {
        {
          id = "shop",
          text_key = "DLG_NATTEBLIK_CHOICE_SHOP",
          action = "open_shop",
          shop_id = "natteblik_maps",
        },
        {
          id = "goodbye",
          text_key = "DLG_NATTEBLIK_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if context.shop_natteblik_maps then
    return {
      speaker = "mapseller_natteblik",
      speaker_name_key = "NPC_MAPSELLER_NATTEBLIK",
      lines = {
        {
          id = "greet",
          text_key = "DLG_NATTEBLIK_GREET",
          voice_key = "voice/mapseller_natteblik/greet",
        },
        {
          id = "ears",
          text_key = "DLG_NATTEBLIK_EARS",
          voice_key = "voice/mapseller_natteblik/ears",
        },
        {
          id = "maps",
          text_key = "DLG_NATTEBLIK_MAPS",
          voice_key = "voice/mapseller_natteblik/maps",
        },
        {
          id = "lantern",
          text_key = "DLG_NATTEBLIK_LANTERN",
          voice_key = "voice/mapseller_natteblik/lantern",
        },
      },
      choices = {
        {
          id = "shop",
          text_key = "DLG_NATTEBLIK_CHOICE_SHOP",
          action = "open_shop",
          shop_id = "natteblik_maps",
        },
        {
          id = "goodbye",
          text_key = "DLG_NATTEBLIK_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  return {
    speaker = "mapseller_natteblik",
    speaker_name_key = "NPC_MAPSELLER_NATTEBLIK",
    lines = {
      {
        id = "greet",
        text_key = "DLG_NATTEBLIK_GREET",
        voice_key = "voice/mapseller_natteblik/greet",
      },
      {
        id = "no_maps",
        text_key = "DLG_NATTEBLIK_NO_MAPS",
        voice_key = "voice/mapseller_natteblik/no_maps",
      },
      {
        id = "farewell",
        text_key = "DLG_NATTEBLIK_FAREWELL",
        voice_key = "voice/mapseller_natteblik/farewell",
      },
    },
    choices = {
      {
        id = "goodbye",
        text_key = "DLG_NATTEBLIK_CHOICE_GOODBYE",
        action = "close",
      },
    },
  }
end
