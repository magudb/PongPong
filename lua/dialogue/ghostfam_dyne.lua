-- dialogue/ghostfam_dyne.lua
-- Mormor Dyne - the round grandmother of the ghost family: spectacles, a coral shawl, a ball of yarn; tells the evening story at the Torvet fire, a short midnight story on the bench after 24:00 (one a weekday), and is the grandmother of a ghost hero (the arrival story, the first meeting).
-- The social layer (S-talk DialogueBridge.decorate) prepends the first-meeting / daily greeting line and appends 'Giv en gave' / 'Fortæl mig om dig' before the close choice
-- (NOT for a scene that returns `social = false`: the cousin's first meeting is such a scene; the finished conversation still counts as met and pays the weekly heart: N04 task 3 / S-talk task 2).
-- Context (P14 task 3): race animal|fairy|hobbit|ghost, hero = the look id, daypart, weekday (0 = Monday) and hour = the STORED game hour 6..25 (24 and 25 are 00:xx and 01:xx of the SAME game day, CLOCK_26),
-- plus every world flag.  The cousin's flags (all JSON-safe bools): ghostfam_kin_<name> (first meeting done) and ghostfam_kin_look_<name> (the look remark said once).  Only unsupported-token-free Lua
-- (no else / elseif / loops): the branches are early returns.

kind = "dialogue"
id = "ghostfam_dyne"

function get_dialogue(context)
  local race = context.race or ""
  local hero = context.hero or ""
  local part = context.daypart or ""
  local hour = context.hour or 0
  local weekday = context.weekday or 0
  local kin_done = context.ghostfam_kin_dyne or false
  local look_done = context.ghostfam_kin_look_dyne or false
  if race == "ghost" and not kin_done then
    api.set_flag("ghostfam_kin_dyne", true)
    api.add_hearts("ghostfam_dyne", 2)
    api.add_item("shirt_knit_cream", 1)
    return {
      speaker = "ghostfam_dyne",
      speaker_name_key = "NPC_GHOSTFAM_DYNE",
      social = false,
      lines = {
        { id = "kin1", text_key = "DLG_GHOSTFAM_DYNE_KIN_1_1", voice_key = "voice/ghostfam_dyne/kin1" },
        { id = "kin2", text_key = "DLG_GHOSTFAM_DYNE_KIN_1_2", voice_key = "voice/ghostfam_dyne/kin2" },
        { id = "kin3", text_key = "DLG_GHOSTFAM_DYNE_KIN_1_3", voice_key = "voice/ghostfam_dyne/kin3" },
        { id = "kin4", text_key = "DLG_GHOSTFAM_DYNE_KIN_1_4", voice_key = "voice/ghostfam_dyne/kin4" },
        { id = "kin5", text_key = "DLG_GHOSTFAM_DYNE_KIN_1_5", voice_key = "voice/ghostfam_dyne/kin5" },
      },
      choices = {
        { id = "thanks", text_key = "DLG_GHOSTFAM_DYNE_KIN_CHOICE_THANKS", action = "close" },
      },
    }
  end
  if hour >= 24 and weekday == 0 then
    return {
      speaker = "ghostfam_dyne",
      speaker_name_key = "NPC_GHOSTFAM_DYNE",
      lines = {
        { id = "midnight", text_key = "DLG_GHOSTFAM_DYNE_MIDNIGHT_0", voice_key = "voice/ghostfam_dyne/midnight" },
      },
      choices = {
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if hour >= 24 and weekday == 1 then
    return {
      speaker = "ghostfam_dyne",
      speaker_name_key = "NPC_GHOSTFAM_DYNE",
      lines = {
        { id = "midnight", text_key = "DLG_GHOSTFAM_DYNE_MIDNIGHT_1", voice_key = "voice/ghostfam_dyne/midnight" },
      },
      choices = {
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if hour >= 24 and weekday == 2 then
    return {
      speaker = "ghostfam_dyne",
      speaker_name_key = "NPC_GHOSTFAM_DYNE",
      lines = {
        { id = "midnight", text_key = "DLG_GHOSTFAM_DYNE_MIDNIGHT_2", voice_key = "voice/ghostfam_dyne/midnight" },
      },
      choices = {
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if hour >= 24 and weekday == 3 then
    return {
      speaker = "ghostfam_dyne",
      speaker_name_key = "NPC_GHOSTFAM_DYNE",
      lines = {
        { id = "midnight", text_key = "DLG_GHOSTFAM_DYNE_MIDNIGHT_3", voice_key = "voice/ghostfam_dyne/midnight" },
      },
      choices = {
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if hour >= 24 and weekday == 4 then
    return {
      speaker = "ghostfam_dyne",
      speaker_name_key = "NPC_GHOSTFAM_DYNE",
      lines = {
        { id = "midnight", text_key = "DLG_GHOSTFAM_DYNE_MIDNIGHT_4", voice_key = "voice/ghostfam_dyne/midnight" },
      },
      choices = {
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if hour >= 24 and weekday == 5 then
    return {
      speaker = "ghostfam_dyne",
      speaker_name_key = "NPC_GHOSTFAM_DYNE",
      lines = {
        { id = "midnight", text_key = "DLG_GHOSTFAM_DYNE_MIDNIGHT_5", voice_key = "voice/ghostfam_dyne/midnight" },
      },
      choices = {
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if hour >= 24 and weekday == 6 then
    return {
      speaker = "ghostfam_dyne",
      speaker_name_key = "NPC_GHOSTFAM_DYNE",
      lines = {
        { id = "midnight", text_key = "DLG_GHOSTFAM_DYNE_MIDNIGHT_6", voice_key = "voice/ghostfam_dyne/midnight" },
      },
      choices = {
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if race == "ghost" and part == "morgen" then
    return {
      speaker = "ghostfam_dyne",
      speaker_name_key = "NPC_GHOSTFAM_DYNE",
      lines = {
        { id = "kin_dawn", text_key = "DLG_GHOSTFAM_DYNE_KIN_DAWN_1", voice_key = "voice/ghostfam_dyne/kin_dawn" },
      },
      choices = {
        { id = "kin_story", text_key = "DLG_GHOSTFAM_DYNE_KIN_CHOICE_STORY", action = "show_info", info_key = "GHOSTFAM_KIN_STORY" },
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if race == "ghost" and hero == "bu" and not look_done then
    api.set_flag("ghostfam_kin_look_dyne", true)
    return {
      speaker = "ghostfam_dyne",
      speaker_name_key = "NPC_GHOSTFAM_DYNE",
      lines = {
        { id = "kin_greet", text_key = "DLG_GHOSTFAM_DYNE_KIN_GREET_1", voice_key = "voice/ghostfam_dyne/kin_greet" },
        { id = "kin_look", text_key = "DLG_GHOSTFAM_DYNE_KIN_LOOK_BU_1", voice_key = "voice/ghostfam_dyne/kin_look" },
      },
      choices = {
        { id = "kin_story", text_key = "DLG_GHOSTFAM_DYNE_KIN_CHOICE_STORY", action = "show_info", info_key = "GHOSTFAM_KIN_STORY" },
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if race == "ghost" and hero == "hviske" and not look_done then
    api.set_flag("ghostfam_kin_look_dyne", true)
    return {
      speaker = "ghostfam_dyne",
      speaker_name_key = "NPC_GHOSTFAM_DYNE",
      lines = {
        { id = "kin_greet", text_key = "DLG_GHOSTFAM_DYNE_KIN_GREET_1", voice_key = "voice/ghostfam_dyne/kin_greet" },
        { id = "kin_look", text_key = "DLG_GHOSTFAM_DYNE_KIN_LOOK_HVISKE_1", voice_key = "voice/ghostfam_dyne/kin_look" },
      },
      choices = {
        { id = "kin_story", text_key = "DLG_GHOSTFAM_DYNE_KIN_CHOICE_STORY", action = "show_info", info_key = "GHOSTFAM_KIN_STORY" },
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if race == "ghost" then
    return {
      speaker = "ghostfam_dyne",
      speaker_name_key = "NPC_GHOSTFAM_DYNE",
      lines = {
        { id = "kin_greet", text_key = "DLG_GHOSTFAM_DYNE_KIN_GREET_1", voice_key = "voice/ghostfam_dyne/kin_greet" },
      },
      choices = {
        { id = "kin_story", text_key = "DLG_GHOSTFAM_DYNE_KIN_CHOICE_STORY", action = "show_info", info_key = "GHOSTFAM_KIN_STORY" },
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if part == "morgen" then
    return {
      speaker = "ghostfam_dyne",
      speaker_name_key = "NPC_GHOSTFAM_DYNE",
      lines = {
        { id = "dawn", text_key = "DLG_GHOSTFAM_DYNE_DAWN_1", voice_key = "voice/ghostfam_dyne/dawn" },
      },
      choices = {
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if part == "nat" then
    return {
      speaker = "ghostfam_dyne",
      speaker_name_key = "NPC_GHOSTFAM_DYNE",
      lines = {
        { id = "night", text_key = "DLG_GHOSTFAM_DYNE_NIGHT_1", voice_key = "voice/ghostfam_dyne/night" },
      },
      choices = {
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  return {
    speaker = "ghostfam_dyne",
    speaker_name_key = "NPC_GHOSTFAM_DYNE",
    lines = {
      { id = "greet", text_key = "DLG_GHOSTFAM_DYNE_GREET_1", voice_key = "voice/ghostfam_dyne/greet" },
    },
    choices = {
      { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
    },
  }
end
