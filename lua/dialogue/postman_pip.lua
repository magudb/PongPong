-- V7: Danish-first draft copy. Voice keys are hooks, not recordings.
kind = "dialogue"
id = "postman_pip"

function get_dialogue(context)
  if context.quest_active_pips_runde then
    return {
      speaker = "postman_pip",
      speaker_name_key = "NPC_POSTMAN_PIP",
      lines = {
        {
          id = "greet",
          text_key = "DLG_PIP_GREET",
          voice_key = "voice/postman_pip/greet",
        },
        {
          id = "remind",
          text_key = "DLG_PIP_REMIND",
          voice_key = "voice/postman_pip/remind",
        },
        {
          id = "round",
          text_key = "DLG_PIP_ROUND",
          voice_key = "voice/postman_pip/round",
        },
      },
      choices = {
        {
          id = "goodbye",
          text_key = "DLG_PIP_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if context.quest_done_pips_runde and context.post_waiting then
    return {
      speaker = "postman_pip",
      speaker_name_key = "NPC_POSTMAN_PIP",
      lines = {
        {
          id = "thanks",
          text_key = "DLG_PIP_THANKS",
          voice_key = "voice/postman_pip/thanks",
        },
        {
          id = "mail",
          text_key = "DLG_PIP_MAIL",
          voice_key = "voice/postman_pip/mail",
        },
        {
          id = "bag",
          text_key = "DLG_PIP_BAG",
          voice_key = "voice/postman_pip/bag",
        },
      },
      choices = {
        {
          id = "goodbye",
          text_key = "DLG_PIP_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if context.quest_done_pips_runde then
    return {
      speaker = "postman_pip",
      speaker_name_key = "NPC_POSTMAN_PIP",
      lines = {
        {
          id = "thanks",
          text_key = "DLG_PIP_THANKS",
          voice_key = "voice/postman_pip/thanks",
        },
        {
          id = "rest",
          text_key = "DLG_PIP_REST",
          voice_key = "voice/postman_pip/rest",
        },
      },
      choices = {
        {
          id = "goodbye",
          text_key = "DLG_PIP_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if context.post_waiting then
    return {
      speaker = "postman_pip",
      speaker_name_key = "NPC_POSTMAN_PIP",
      lines = {
        {
          id = "greet",
          text_key = "DLG_PIP_GREET",
          voice_key = "voice/postman_pip/greet",
        },
        {
          id = "mail",
          text_key = "DLG_PIP_MAIL",
          voice_key = "voice/postman_pip/mail",
        },
        {
          id = "offer",
          text_key = "DLG_PIP_OFFER",
          voice_key = "voice/postman_pip/offer",
        },
      },
      choices = {
        {
          id = "quest",
          text_key = "DLG_PIP_CHOICE_QUEST",
          action = "quest_accept",
          quest_id = "pips_runde",
        },
        {
          id = "goodbye",
          text_key = "DLG_PIP_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  return {
    speaker = "postman_pip",
    speaker_name_key = "NPC_POSTMAN_PIP",
    lines = {
      {
        id = "greet",
        text_key = "DLG_PIP_GREET",
        voice_key = "voice/postman_pip/greet",
      },
      {
        id = "bag",
        text_key = "DLG_PIP_BAG",
        voice_key = "voice/postman_pip/bag",
      },
      {
        id = "offer",
        text_key = "DLG_PIP_OFFER",
        voice_key = "voice/postman_pip/offer",
      },
    },
    choices = {
      {
        id = "quest",
        text_key = "DLG_PIP_CHOICE_QUEST",
        action = "quest_accept",
        quest_id = "pips_runde",
      },
      {
        id = "goodbye",
        text_key = "DLG_PIP_CHOICE_GOODBYE",
        action = "close",
      },
    },
  }
end
