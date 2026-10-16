-- dialogue/baker_maja.lua
-- Bager Maja — warm, always hungry for fresh crops, cookie recipes.
-- Also hosts the addition/subtraction problems for math_bakery_counts.

kind = "dialogue"
id = "baker_maja"

function get_dialogue(context)
  local roof_fixed = context.maja_roof_fixed or false
  local quiz_active = context.math_bakery_active or false
  local quiz_done = context.math_bakery_done or false
  local q1 = context.math_maja_q1 or false
  local q2 = context.math_maja_q2 or false
  local q3 = context.math_maja_q3 or false

  -- Math quest done: thank the player.
  if quiz_done then
    return {
      speaker = "baker_maja",
      speaker_name_key = "NPC_BAKER_MAJA",
      lines = {
        {
          id = "math_done",
          text_key = "DLG_MAJA_MATH_DONE",
          voice_key = "voice/baker_maja/math_done",
        },
      },
      choices = {
        {
          id = "buy_cookies",
          text_key = "DLG_CHOICE_BUY_COOKIES",
          action = "open_shop",
          shop_id = "bakery",
        },
        {
          id = "goodbye",
          text_key = "DLG_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end

  -- Math quest in progress: present the next unsolved problem.
  if quiz_active and not q1 then
    return {
      speaker = "baker_maja",
      speaker_name_key = "NPC_BAKER_MAJA",
      lines = {
        {
          id = "math_q1",
          text_key = "DLG_MAJA_MATH_Q1",
          voice_key = "voice/baker_maja/math_q1",
        },
      },
      choices = {
        {
          id = "q1_a",
          text_key = "12",
          action = "math_answer",
          answer = 12,
          correct = 18,
          quest_id = "math_bakery_counts",
          objective_id = "math_maja_q1",
          result_flag = "math_maja_q1",
        },
        {
          id = "q1_b",
          text_key = "18",
          action = "math_answer",
          answer = 18,
          correct = 18,
          quest_id = "math_bakery_counts",
          objective_id = "math_maja_q1",
          result_flag = "math_maja_q1",
        },
        {
          id = "q1_c",
          text_key = "22",
          action = "math_answer",
          answer = 22,
          correct = 18,
          quest_id = "math_bakery_counts",
          objective_id = "math_maja_q1",
          result_flag = "math_maja_q1",
        },
      },
    }
  end

  if quiz_active and not q2 then
    return {
      speaker = "baker_maja",
      speaker_name_key = "NPC_BAKER_MAJA",
      lines = {
        {
          id = "math_q2",
          text_key = "DLG_MAJA_MATH_Q2",
          voice_key = "voice/baker_maja/math_q2",
        },
      },
      choices = {
        {
          id = "q2_a",
          text_key = "43",
          action = "math_answer",
          answer = 43,
          correct = 43,
          quest_id = "math_bakery_counts",
          objective_id = "math_maja_q2",
          result_flag = "math_maja_q2",
        },
        {
          id = "q2_b",
          text_key = "33",
          action = "math_answer",
          answer = 33,
          correct = 43,
          quest_id = "math_bakery_counts",
          objective_id = "math_maja_q2",
          result_flag = "math_maja_q2",
        },
        {
          id = "q2_c",
          text_key = "45",
          action = "math_answer",
          answer = 45,
          correct = 43,
          quest_id = "math_bakery_counts",
          objective_id = "math_maja_q2",
          result_flag = "math_maja_q2",
        },
      },
    }
  end

  if quiz_active and not q3 then
    return {
      speaker = "baker_maja",
      speaker_name_key = "NPC_BAKER_MAJA",
      lines = {
        {
          id = "math_q3",
          text_key = "DLG_MAJA_MATH_Q3",
          voice_key = "voice/baker_maja/math_q3",
        },
      },
      choices = {
        {
          id = "q3_a",
          text_key = "45",
          action = "math_answer",
          answer = 45,
          correct = 35,
          quest_id = "math_bakery_counts",
          objective_id = "math_maja_q3",
          result_flag = "math_maja_q3",
        },
        {
          id = "q3_b",
          text_key = "39",
          action = "math_answer",
          answer = 39,
          correct = 35,
          quest_id = "math_bakery_counts",
          objective_id = "math_maja_q3",
          result_flag = "math_maja_q3",
        },
        {
          id = "q3_c",
          text_key = "35",
          action = "math_answer",
          answer = 35,
          correct = 35,
          quest_id = "math_bakery_counts",
          objective_id = "math_maja_q3",
          result_flag = "math_maja_q3",
        },
      },
    }
  end

  if not roof_fixed then
    return {
      speaker = "baker_maja",
      speaker_name_key = "NPC_BAKER_MAJA",
      lines = {
        {
          id = "greet",
          text_key = "DLG_MAJA_GREET",
          voice_key = "voice/baker_maja/greet",
        },
        {
          id = "roof_trouble",
          text_key = "DLG_MAJA_ROOF_TROUBLE",
          voice_key = "voice/baker_maja/roof_trouble",
        },
      },
      choices = {
        {
          id = "help_roof",
          text_key = "DLG_CHOICE_HELP_ROOF",
          action = "quest_accept",
          quest_id = "fix_roof",
        },
        {
          id = "math_quest",
          text_key = "DLG_CHOICE_MATH_BAKERY",
          action = "quest_accept",
          quest_id = "math_bakery_counts",
        },
        {
          id = "buy_cookies",
          text_key = "DLG_CHOICE_BUY_COOKIES",
          action = "open_shop",
          shop_id = "bakery",
        },
        {
          id = "goodbye",
          text_key = "DLG_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end

  return {
    speaker = "baker_maja",
    speaker_name_key = "NPC_BAKER_MAJA",
    lines = {
      {
        id = "thanks",
        text_key = "DLG_MAJA_THANKS",
        voice_key = "voice/baker_maja/thanks",
      },
      {
        id = "cookie_talk",
        text_key = "DLG_MAJA_COOKIE_TALK",
        voice_key = "voice/baker_maja/cookie_talk",
      },
    },
    choices = {
      {
        id = "cookie_quest",
        text_key = "DLG_CHOICE_COOKIE_QUEST",
        action = "quest_offer",
        quest_id = "cookie_delivery",
      },
      {
        id = "math_quest",
        text_key = "DLG_CHOICE_MATH_BAKERY",
        action = "quest_accept",
        quest_id = "math_bakery_counts",
      },
      {
        id = "buy_cookies",
        text_key = "DLG_CHOICE_BUY_COOKIES",
        action = "open_shop",
        shop_id = "bakery",
      },
      {
        id = "goodbye",
        text_key = "DLG_CHOICE_GOODBYE",
        action = "close",
      },
    },
  }
end
