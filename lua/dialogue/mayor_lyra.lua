-- dialogue/mayor_lyra.lua
-- Feborgmester Lyra — welcoming, wise, slightly dramatic.

kind = "dialogue"
id = "mayor_lyra"

function get_dialogue(context)
  local intro_done = context.intro_done or false
  if not intro_done then
    return {
      speaker = "mayor_lyra",
      speaker_name_key = "NPC_MAYOR_LYRA",
      lines = {
        {
          id = "greet_1",
          text_key = "DIALOGUE_LYRA_GREET_1",
          voice_key = "voice/lyra/greet_1",
        },
        {
          id = "greet_2",
          text_key = "DIALOGUE_LYRA_GREET_2",
          voice_key = "voice/lyra/greet_2",
        },
        {
          id = "lottery",
          text_key = "DIALOGUE_LYRA_LOTTERY",
          voice_key = "voice/lyra/lottery",
        },
      },
      choices = {
        {
          id = "accept_farm",
          text_key = "DIALOGUE_CHOICE_ACCEPT_FARM",
          action = "quest_accept",
          quest_id = "intro_lottery",
        },
        {
          id = "ask_more",
          text_key = "DIALOGUE_CHOICE_ASK_MORE",
          action = "show_info",
          info_key = "INFO_LOTTERY",
        },
      },
    }
  end

  return {
    speaker = "mayor_lyra",
    speaker_name_key = "NPC_MAYOR_LYRA",
    lines = {
      {
        id = "hello",
        text_key = "DIALOGUE_LYRA_HELLO",
        voice_key = "voice/lyra/hello",
      },
      {
        id = "farm_status",
        text_key = "DIALOGUE_LYRA_FARM_STATUS",
        voice_key = "voice/lyra/farm_status",
      },
    },
    choices = {
      {
        id = "about_quests",
        text_key = "DIALOGUE_CHOICE_ABOUT_QUESTS",
        action = "open_journal",
      },
      {
        id = "goodbye",
        text_key = "DIALOGUE_CHOICE_GOODBYE",
        action = "close",
      },
    },
  }
end

function handle_event(event, payload)
  if event == "quest_accepted" then
    api.log("Lyra: Godt! Din gård venter.")
  end
end
