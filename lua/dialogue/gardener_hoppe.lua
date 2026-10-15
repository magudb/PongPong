-- V7: Danish-first draft copy. Voice keys are hooks, not recordings.
kind = "dialogue"
id = "gardener_hoppe"

function get_dialogue(context)
  if context.weather == "klart" and context.swap_day == context.total_day then
    return {
      speaker = "gardener_hoppe",
      speaker_name_key = "NPC_GARDENER_HOPPE",
      lines = {
        {
          id = "greet",
          text_key = "DLG_HOPPE_GREET",
          voice_key = "voice/gardener_hoppe/greet",
        },
        {
          id = "klart",
          text_key = "DLG_HOPPE_KLART",
          voice_key = "voice/gardener_hoppe/klart",
        },
        {
          id = "swap_done",
          text_key = "DLG_HOPPE_SWAP_DONE",
          voice_key = "voice/gardener_hoppe/swap_done",
        },
        {
          id = "once",
          text_key = "DLG_HOPPE_ONCE",
          voice_key = "voice/gardener_hoppe/once",
        },
      },
      choices = {
        {
          id = "goodbye",
          text_key = "DLG_HOPPE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if context.weather == "klart" then
    return {
      speaker = "gardener_hoppe",
      speaker_name_key = "NPC_GARDENER_HOPPE",
      lines = {
        {
          id = "greet",
          text_key = "DLG_HOPPE_GREET",
          voice_key = "voice/gardener_hoppe/greet",
        },
        {
          id = "klart",
          text_key = "DLG_HOPPE_KLART",
          voice_key = "voice/gardener_hoppe/klart",
        },
        {
          id = "swap_offer",
          text_key = "DLG_HOPPE_SWAP_OFFER",
          voice_key = "voice/gardener_hoppe/swap_offer",
        },
      },
      choices = {
        {
          id = "swap",
          text_key = "DLG_HOPPE_CHOICE_SWAP",
          action = "emit_event",
          event = "swap_seeds_request",
          npc = "gardener_hoppe",
        },
        {
          id = "goodbye",
          text_key = "DLG_HOPPE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if context.weather == "regn" and context.swap_day == context.total_day then
    return {
      speaker = "gardener_hoppe",
      speaker_name_key = "NPC_GARDENER_HOPPE",
      lines = {
        {
          id = "greet",
          text_key = "DLG_HOPPE_GREET",
          voice_key = "voice/gardener_hoppe/greet",
        },
        {
          id = "regn",
          text_key = "DLG_HOPPE_REGN",
          voice_key = "voice/gardener_hoppe/regn",
        },
        {
          id = "swap_done",
          text_key = "DLG_HOPPE_SWAP_DONE",
          voice_key = "voice/gardener_hoppe/swap_done",
        },
        {
          id = "once",
          text_key = "DLG_HOPPE_ONCE",
          voice_key = "voice/gardener_hoppe/once",
        },
      },
      choices = {
        {
          id = "goodbye",
          text_key = "DLG_HOPPE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if context.weather == "regn" then
    return {
      speaker = "gardener_hoppe",
      speaker_name_key = "NPC_GARDENER_HOPPE",
      lines = {
        {
          id = "greet",
          text_key = "DLG_HOPPE_GREET",
          voice_key = "voice/gardener_hoppe/greet",
        },
        {
          id = "regn",
          text_key = "DLG_HOPPE_REGN",
          voice_key = "voice/gardener_hoppe/regn",
        },
        {
          id = "swap_offer",
          text_key = "DLG_HOPPE_SWAP_OFFER",
          voice_key = "voice/gardener_hoppe/swap_offer",
        },
      },
      choices = {
        {
          id = "swap",
          text_key = "DLG_HOPPE_CHOICE_SWAP",
          action = "emit_event",
          event = "swap_seeds_request",
          npc = "gardener_hoppe",
        },
        {
          id = "goodbye",
          text_key = "DLG_HOPPE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if context.weather == "taage" and context.swap_day == context.total_day then
    return {
      speaker = "gardener_hoppe",
      speaker_name_key = "NPC_GARDENER_HOPPE",
      lines = {
        {
          id = "greet",
          text_key = "DLG_HOPPE_GREET",
          voice_key = "voice/gardener_hoppe/greet",
        },
        {
          id = "taage",
          text_key = "DLG_HOPPE_TAAGE",
          voice_key = "voice/gardener_hoppe/taage",
        },
        {
          id = "swap_done",
          text_key = "DLG_HOPPE_SWAP_DONE",
          voice_key = "voice/gardener_hoppe/swap_done",
        },
        {
          id = "once",
          text_key = "DLG_HOPPE_ONCE",
          voice_key = "voice/gardener_hoppe/once",
        },
      },
      choices = {
        {
          id = "goodbye",
          text_key = "DLG_HOPPE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if context.weather == "taage" then
    return {
      speaker = "gardener_hoppe",
      speaker_name_key = "NPC_GARDENER_HOPPE",
      lines = {
        {
          id = "greet",
          text_key = "DLG_HOPPE_GREET",
          voice_key = "voice/gardener_hoppe/greet",
        },
        {
          id = "taage",
          text_key = "DLG_HOPPE_TAAGE",
          voice_key = "voice/gardener_hoppe/taage",
        },
        {
          id = "swap_offer",
          text_key = "DLG_HOPPE_SWAP_OFFER",
          voice_key = "voice/gardener_hoppe/swap_offer",
        },
      },
      choices = {
        {
          id = "swap",
          text_key = "DLG_HOPPE_CHOICE_SWAP",
          action = "emit_event",
          event = "swap_seeds_request",
          npc = "gardener_hoppe",
        },
        {
          id = "goodbye",
          text_key = "DLG_HOPPE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if context.weather == "sne" and context.swap_day == context.total_day then
    return {
      speaker = "gardener_hoppe",
      speaker_name_key = "NPC_GARDENER_HOPPE",
      lines = {
        {
          id = "greet",
          text_key = "DLG_HOPPE_GREET",
          voice_key = "voice/gardener_hoppe/greet",
        },
        {
          id = "sne",
          text_key = "DLG_HOPPE_SNE",
          voice_key = "voice/gardener_hoppe/sne",
        },
        {
          id = "swap_done",
          text_key = "DLG_HOPPE_SWAP_DONE",
          voice_key = "voice/gardener_hoppe/swap_done",
        },
        {
          id = "once",
          text_key = "DLG_HOPPE_ONCE",
          voice_key = "voice/gardener_hoppe/once",
        },
      },
      choices = {
        {
          id = "goodbye",
          text_key = "DLG_HOPPE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if context.weather == "sne" then
    return {
      speaker = "gardener_hoppe",
      speaker_name_key = "NPC_GARDENER_HOPPE",
      lines = {
        {
          id = "greet",
          text_key = "DLG_HOPPE_GREET",
          voice_key = "voice/gardener_hoppe/greet",
        },
        {
          id = "sne",
          text_key = "DLG_HOPPE_SNE",
          voice_key = "voice/gardener_hoppe/sne",
        },
        {
          id = "swap_offer",
          text_key = "DLG_HOPPE_SWAP_OFFER",
          voice_key = "voice/gardener_hoppe/swap_offer",
        },
      },
      choices = {
        {
          id = "swap",
          text_key = "DLG_HOPPE_CHOICE_SWAP",
          action = "emit_event",
          event = "swap_seeds_request",
          npc = "gardener_hoppe",
        },
        {
          id = "goodbye",
          text_key = "DLG_HOPPE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if context.weather == "torden" and context.swap_day == context.total_day then
    return {
      speaker = "gardener_hoppe",
      speaker_name_key = "NPC_GARDENER_HOPPE",
      lines = {
        {
          id = "greet",
          text_key = "DLG_HOPPE_GREET",
          voice_key = "voice/gardener_hoppe/greet",
        },
        {
          id = "torden",
          text_key = "DLG_HOPPE_TORDEN",
          voice_key = "voice/gardener_hoppe/torden",
        },
        {
          id = "swap_done",
          text_key = "DLG_HOPPE_SWAP_DONE",
          voice_key = "voice/gardener_hoppe/swap_done",
        },
        {
          id = "once",
          text_key = "DLG_HOPPE_ONCE",
          voice_key = "voice/gardener_hoppe/once",
        },
      },
      choices = {
        {
          id = "goodbye",
          text_key = "DLG_HOPPE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if context.weather == "torden" then
    return {
      speaker = "gardener_hoppe",
      speaker_name_key = "NPC_GARDENER_HOPPE",
      lines = {
        {
          id = "greet",
          text_key = "DLG_HOPPE_GREET",
          voice_key = "voice/gardener_hoppe/greet",
        },
        {
          id = "torden",
          text_key = "DLG_HOPPE_TORDEN",
          voice_key = "voice/gardener_hoppe/torden",
        },
        {
          id = "swap_offer",
          text_key = "DLG_HOPPE_SWAP_OFFER",
          voice_key = "voice/gardener_hoppe/swap_offer",
        },
      },
      choices = {
        {
          id = "swap",
          text_key = "DLG_HOPPE_CHOICE_SWAP",
          action = "emit_event",
          event = "swap_seeds_request",
          npc = "gardener_hoppe",
        },
        {
          id = "goodbye",
          text_key = "DLG_HOPPE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if context.swap_day == context.total_day then
    return {
      speaker = "gardener_hoppe",
      speaker_name_key = "NPC_GARDENER_HOPPE",
      lines = {
        {
          id = "greet",
          text_key = "DLG_HOPPE_GREET",
          voice_key = "voice/gardener_hoppe/greet",
        },
        {
          id = "swap_done",
          text_key = "DLG_HOPPE_SWAP_DONE",
          voice_key = "voice/gardener_hoppe/swap_done",
        },
        {
          id = "once",
          text_key = "DLG_HOPPE_ONCE",
          voice_key = "voice/gardener_hoppe/once",
        },
      },
      choices = {
        {
          id = "goodbye",
          text_key = "DLG_HOPPE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  return {
    speaker = "gardener_hoppe",
    speaker_name_key = "NPC_GARDENER_HOPPE",
    lines = {
      {
        id = "greet",
        text_key = "DLG_HOPPE_GREET",
        voice_key = "voice/gardener_hoppe/greet",
      },
      {
        id = "sprouts",
        text_key = "DLG_HOPPE_SPROUTS",
        voice_key = "voice/gardener_hoppe/sprouts",
      },
      {
        id = "swap_offer",
        text_key = "DLG_HOPPE_SWAP_OFFER",
        voice_key = "voice/gardener_hoppe/swap_offer",
      },
    },
    choices = {
      {
        id = "swap",
        text_key = "DLG_HOPPE_CHOICE_SWAP",
        action = "emit_event",
        event = "swap_seeds_request",
        npc = "gardener_hoppe",
      },
      {
        id = "goodbye",
        text_key = "DLG_HOPPE_CHOICE_GOODBYE",
        action = "close",
      },
    },
  }
end
