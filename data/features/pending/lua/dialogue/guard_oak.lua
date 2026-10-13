-- dialogue/guard_oak.lua  (PENDING REFERENCE, tested by the F1 validator in wave 3; P14 merges the snurresvampen branch into its own rewrite of this file)
-- Guard Oak: protects the forest edge.  Offers forest_patrol always and the boss quest snurresvampen (gate of home tier 8) until it is active or done.
-- Flags come from the quest hooks of lua/quests/snurresvampen.lua; the locals are ALWAYS booleans (an unset flag compared with == raises in the project interpreter).

kind = "dialogue"
id = "guard_oak"

function get_dialogue(context)
  local sv_active = context.snurresvampen_active or snurresvampen_active or false
  local sv_done = context.snurresvampen_done or snurresvampen_done or false
  if sv_active then
    return {
      speaker = "guard_oak",
      speaker_name_key = "NPC_GUARD_OAK",
      lines = {
        {
          id = "snurre_remind",
          text_key = "QUEST_SNURRESVAMPEN_REMIND",
          voice_key = "voice/guard_oak/snurre_remind",
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
  if not sv_done then
    return {
      speaker = "guard_oak",
      speaker_name_key = "NPC_GUARD_OAK",
      lines = {
        {
          id = "greet",
          text_key = "DIALOGUE_OAK_GREET",
          voice_key = "voice/oak/greet",
        },
        {
          id = "snurre_offer",
          text_key = "QUEST_SNURRESVAMPEN_OFFER",
          voice_key = "voice/guard_oak/snurre_offer",
        },
      },
      choices = {
        {
          id = "patrol_quest",
          text_key = "DIALOGUE_CHOICE_MINING_QUEST",
          action = "quest_accept",
          quest_id = "forest_patrol",
        },
        {
          id = "snurre_quest",
          text_key = "QUEST_SNURRESVAMPEN_CHOICE",
          action = "quest_accept",
          quest_id = "snurresvampen",
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
    speaker = "guard_oak",
    speaker_name_key = "NPC_GUARD_OAK",
    lines = {
      {
        id = "greet",
        text_key = "DIALOGUE_OAK_GREET",
        voice_key = "voice/oak/greet",
      },
    },
    choices = {
      {
        id = "patrol_quest",
        text_key = "DIALOGUE_CHOICE_MINING_QUEST",
        action = "quest_accept",
        quest_id = "forest_patrol",
      },
      {
        id = "goodbye",
        text_key = "DIALOGUE_CHOICE_GOODBYE",
        action = "close",
      },
    },
  }
end
