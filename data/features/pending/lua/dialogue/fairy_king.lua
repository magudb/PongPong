-- dialogue/fairy_king.lua  (PENDING REFERENCE, tested by the F1 validator in wave 3; P14 merges the two quest branches into its own fairy_king.lua, which also holds the intro letter)
-- The Fairy King offers moonstone_crown (gate of home tier 9) until it is active or done, and slotsdroemmen (the castle's final quest) while the home is tier 10.
-- home_tier is read as a NUMBER with a default, so the comparison cannot raise.

kind = "dialogue"
id = "fairy_king"

function get_dialogue(context)
  local tier = context.home_tier or home_tier or 1
  local mc_active = context.moonstone_crown_active or moonstone_crown_active or false
  local mc_done = context.moonstone_crown_done or moonstone_crown_done or false
  local sl_active = context.slotsdroemmen_active or slotsdroemmen_active or false
  local sl_done = context.slotsdroemmen_done or slotsdroemmen_done or false
  if sl_active then
    return {
      speaker = "fairy_king",
      speaker_name_key = "NPC_FAIRY_KING",
      lines = {
        {
          id = "slot_remind",
          text_key = "QUEST_SLOTSDROEMMEN_REMIND",
          voice_key = "voice/fairy_king/slot_remind",
        },
      },
      choices = {
        {
          id = "goodbye",
          text_key = "DIALOGUE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if tier == 10 and not sl_done then
    return {
      speaker = "fairy_king",
      speaker_name_key = "NPC_FAIRY_KING",
      lines = {
        {
          id = "slot_offer",
          text_key = "QUEST_SLOTSDROEMMEN_OFFER",
          voice_key = "voice/fairy_king/slot_offer",
        },
      },
      choices = {
        {
          id = "slot_quest",
          text_key = "QUEST_SLOTSDROEMMEN_CHOICE",
          action = "quest_accept",
          quest_id = "slotsdroemmen",
        },
        {
          id = "goodbye",
          text_key = "DIALOGUE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if mc_active then
    return {
      speaker = "fairy_king",
      speaker_name_key = "NPC_FAIRY_KING",
      lines = {
        {
          id = "moon_remind",
          text_key = "QUEST_MOONSTONE_CROWN_REMIND",
          voice_key = "voice/fairy_king/moon_remind",
        },
      },
      choices = {
        {
          id = "goodbye",
          text_key = "DIALOGUE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if not mc_done then
    return {
      speaker = "fairy_king",
      speaker_name_key = "NPC_FAIRY_KING",
      lines = {
        {
          id = "moon_offer",
          text_key = "QUEST_MOONSTONE_CROWN_OFFER",
          voice_key = "voice/fairy_king/moon_offer",
        },
      },
      choices = {
        {
          id = "moon_quest",
          text_key = "QUEST_MOONSTONE_CROWN_CHOICE",
          action = "quest_accept",
          quest_id = "moonstone_crown",
        },
        {
          id = "goodbye",
          text_key = "DIALOGUE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  return {
    speaker = "fairy_king",
    speaker_name_key = "NPC_FAIRY_KING",
    lines = {
      {
        id = "greet",
        text_key = "DLG_KING_GREET",
        voice_key = "voice/fairy_king/greet",
      },
    },
    choices = {
      {
        id = "goodbye",
        text_key = "DIALOGUE_CHOICE_GOODBYE",
        action = "close",
      },
    },
  }
end
