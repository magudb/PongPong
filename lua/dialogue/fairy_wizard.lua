-- dialogue/fairy_wizard.lua  (PENDING REFERENCE = the repo's current file + the bogtraeet branches; P14 merges the branches into its own rewrite)
-- dialogue/fairy_wizard.lua
-- Fairy wizard Zephyr — runs the magic store in fairy city.
-- Also hosts the multiplication riddles for the math_wizard_quiz quest.

kind = "dialogue"
id = "fairy_wizard"

function get_dialogue(context)
  local quiz_active = context.math_quiz_active or false
  local quiz_done = context.math_quiz_done or false
  local q1 = context.math_wiz_q1 or false
  local q2 = context.math_wiz_q2 or false
  local q3 = context.math_wiz_q3 or false

  -- FEATURES: the maths-chain reward quest bogtraeet (unique Book Tree).  Offered once the three math flags are set; reminder while it is active.
  local m1 = context.math_bakery_done or math_bakery_done or false
  local m2 = context.math_harvest_done or math_harvest_done or false
  local m3 = context.math_quiz_done or math_quiz_done or false
  local bt_active = context.bogtraeet_active or bogtraeet_active or false
  local bt_done = context.bogtraeet_done or bogtraeet_done or false
  if bt_active then
    return {
      speaker = "fairy_wizard",
      speaker_name_key = "NPC_FAIRY_WIZARD",
      lines = {
        {
          id = "bogtrae_remind",
          text_key = "QUEST_BOGTRAEET_REMIND",
          voice_key = "voice/fairy_wizard/bogtrae_remind",
        },
      },
      choices = {
        {
          id = "goodbye",
          text_key = "DLG_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if m1 and m2 and m3 and not bt_done then
    return {
      speaker = "fairy_wizard",
      speaker_name_key = "NPC_FAIRY_WIZARD",
      lines = {
        {
          id = "bogtrae_offer",
          text_key = "QUEST_BOGTRAEET_OFFER",
          voice_key = "voice/fairy_wizard/bogtrae_offer",
        },
      },
      choices = {
        {
          id = "bogtrae_quest",
          text_key = "QUEST_BOGTRAEET_CHOICE",
          action = "quest_accept",
          quest_id = "bogtraeet",
        },
        {
          id = "goodbye",
          text_key = "DLG_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end

  -- Quiz finished: thank the player, then back to normal shop talk.
  if quiz_done then
    return {
      speaker = "fairy_wizard",
      speaker_name_key = "NPC_FAIRY_WIZARD",
      lines = {
        {
          id = "math_done",
          text_key = "DLG_WIZARD_MATH_DONE",
          voice_key = "voice/fairy_wizard/math_done",
        },
      },
      choices = {
        {
          id = "open_shop",
          text_key = "DLG_CHOICE_OPEN_SHOP",
          action = "open_shop",
          shop_id = "magic_store",
        },
        {
          id = "goodbye",
          text_key = "DLG_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end

  -- Quiz in progress: present the next unanswered riddle.
  if quiz_active and not q1 then
    return {
      speaker = "fairy_wizard",
      speaker_name_key = "NPC_FAIRY_WIZARD",
      lines = {
        {
          id = "math_q1",
          text_key = "DLG_WIZARD_MATH_Q1",
          voice_key = "voice/fairy_wizard/math_q1",
        },
      },
      choices = {
        {
          id = "q1_a",
          text_key = "36",
          action = "math_answer",
          answer = 36,
          correct = 42,
          quest_id = "math_wizard_quiz",
          objective_id = "math_wiz_q1",
          result_flag = "math_wiz_q1",
        },
        {
          id = "q1_b",
          text_key = "42",
          action = "math_answer",
          answer = 42,
          correct = 42,
          quest_id = "math_wizard_quiz",
          objective_id = "math_wiz_q1",
          result_flag = "math_wiz_q1",
        },
        {
          id = "q1_c",
          text_key = "48",
          action = "math_answer",
          answer = 48,
          correct = 42,
          quest_id = "math_wizard_quiz",
          objective_id = "math_wiz_q1",
          result_flag = "math_wiz_q1",
        },
      },
    }
  end

  if quiz_active and not q2 then
    return {
      speaker = "fairy_wizard",
      speaker_name_key = "NPC_FAIRY_WIZARD",
      lines = {
        {
          id = "math_q2",
          text_key = "DLG_WIZARD_MATH_Q2",
          voice_key = "voice/fairy_wizard/math_q2",
        },
      },
      choices = {
        {
          id = "q2_a",
          text_key = "64",
          action = "math_answer",
          answer = 64,
          correct = 72,
          quest_id = "math_wizard_quiz",
          objective_id = "math_wiz_q2",
          result_flag = "math_wiz_q2",
        },
        {
          id = "q2_b",
          text_key = "81",
          action = "math_answer",
          answer = 81,
          correct = 72,
          quest_id = "math_wizard_quiz",
          objective_id = "math_wiz_q2",
          result_flag = "math_wiz_q2",
        },
        {
          id = "q2_c",
          text_key = "72",
          action = "math_answer",
          answer = 72,
          correct = 72,
          quest_id = "math_wizard_quiz",
          objective_id = "math_wiz_q2",
          result_flag = "math_wiz_q2",
        },
      },
    }
  end

  if quiz_active and not q3 then
    return {
      speaker = "fairy_wizard",
      speaker_name_key = "NPC_FAIRY_WIZARD",
      lines = {
        {
          id = "math_q3",
          text_key = "DLG_WIZARD_MATH_Q3",
          voice_key = "voice/fairy_wizard/math_q3",
        },
      },
      choices = {
        {
          id = "q3_a",
          text_key = "24",
          action = "math_answer",
          answer = 24,
          correct = 28,
          quest_id = "math_wizard_quiz",
          objective_id = "math_wiz_q3",
          result_flag = "math_wiz_q3",
        },
        {
          id = "q3_b",
          text_key = "28",
          action = "math_answer",
          answer = 28,
          correct = 28,
          quest_id = "math_wizard_quiz",
          objective_id = "math_wiz_q3",
          result_flag = "math_wiz_q3",
        },
        {
          id = "q3_c",
          text_key = "32",
          action = "math_answer",
          answer = 32,
          correct = 28,
          quest_id = "math_wizard_quiz",
          objective_id = "math_wiz_q3",
          result_flag = "math_wiz_q3",
        },
      },
    }
  end

  -- Default: greet, offer the quiz, shop and smalltalk.
  return {
    speaker = "fairy_wizard",
    speaker_name_key = "NPC_FAIRY_WIZARD",
    lines = {
      {
        id = "greet",
        text_key = "DLG_WIZARD_GREET",
        voice_key = "voice/fairy_wizard/greet",
      },
      {
        id = "math_intro",
        text_key = "DLG_WIZARD_MATH_INTRO",
        voice_key = "voice/fairy_wizard/math_intro",
      },
    },
    choices = {
      {
        id = "take_quiz",
        text_key = "DLG_CHOICE_MATH_QUIZ",
        action = "quest_accept",
        quest_id = "math_wizard_quiz",
      },
      {
        id = "open_shop",
        text_key = "DLG_CHOICE_OPEN_SHOP",
        action = "open_shop",
        shop_id = "magic_store",
      },
      {
        id = "about_magic",
        text_key = "DLG_CHOICE_ABOUT_MAGIC",
        action = "show_info",
        info_key = "INFO_MAGIC",
      },
      {
        id = "goodbye",
        text_key = "DLG_CHOICE_GOODBYE",
        action = "close",
      },
    },
  }
end
