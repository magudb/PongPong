-- dialogue/mayor_lyra.lua
-- Feborgmester Lyra — welcoming, wise, slightly dramatic.

kind = "dialogue"
id = "mayor_lyra"

function get_dialogue(context)
  local intro_done = context.mayor_welcome_seen or
    (context.quest_done_intro_lottery and not context.mayor_welcome_pending) or false
  if not intro_done then
    return {
      speaker = "mayor_lyra",
      mayor_welcome = true,
      speaker_name_key = "NPC_MAYOR_LYRA",
      lines = {
        {
          id = "greet_1",
          text_key = "DLG_LYRA_GREET_1",
          voice_key = "voice/mayor_lyra/greet_1",
        },
        {
          id = "greet_2",
          text_key = "DLG_LYRA_GREET_2",
          voice_key = "voice/mayor_lyra/greet_2",
        },
        {
          id = "lottery",
          text_key = "DLG_LYRA_LOTTERY",
          voice_key = "voice/mayor_lyra/lottery",
        },
      },
      choices = {
        {
          id = "accept_farm",
          text_key = "DLG_CHOICE_ACCEPT_FARM",
          action = "quest_accept",
          quest_id = "intro_lottery",
        },
        {
          id = "ask_more",
          text_key = "DLG_CHOICE_ASK_MORE",
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
        text_key = "DLG_LYRA_HELLO",
        voice_key = "voice/mayor_lyra/hello",
      },
      {
        id = "farm_status",
        text_key = "DLG_LYRA_FARM_STATUS",
        voice_key = "voice/mayor_lyra/farm_status",
      },
    },
    choices = {
      {
        id = "about_quests",
        text_key = "DLG_CHOICE_ABOUT_QUESTS",
        action = "open_journal",
      },
      {
        id = "goodbye",
        text_key = "DLG_CHOICE_GOODBYE",
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
