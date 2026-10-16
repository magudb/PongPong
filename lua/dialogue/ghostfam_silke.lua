-- dialogue/ghostfam_silke.lua
-- Mor Silke - the mother and the night watch: a bow and a lantern; patrols the Torvet and Hyggebyen in the evening, the Traetoppen lamps after 23:00, puts out the last lamp at dawn; she knows where Blund hides (the choice 'Hvor gemmer Blund sig?' shows the hint of the weekday and slot: the same table as lua/config/ghostfam_seek.lua) and is a ghost hero's relative.
-- The social layer (S-talk DialogueBridge.decorate) prepends the first-meeting / daily greeting line and appends 'Giv en gave' / 'Fortæl mig om dig' before the close choice
-- (NOT for a scene that returns `social = false`: the cousin's first meeting is such a scene; the finished conversation still counts as met and pays the weekly heart: N04 task 3 / S-talk task 2).
-- Context (P14 task 3): race animal|fairy|hobbit|ghost, hero = the look id, daypart, weekday (0 = Monday) and hour = the STORED game hour 6..25 (24 and 25 are 00:xx and 01:xx of the SAME game day, CLOCK_26),
-- plus every world flag.  The cousin's flags (all JSON-safe bools): ghostfam_kin_<name> (first meeting done) and ghostfam_kin_look_<name> (the look remark said once).  Only unsupported-token-free Lua
-- (no else / elseif / loops): the branches are early returns.

kind = "dialogue"
id = "ghostfam_silke"

function get_dialogue(context)
  local race = context.race or ""
  local hero = context.hero or ""
  local part = context.daypart or ""
  local hour = context.hour or 0
  local weekday = context.weekday or 0
  local kin_done = context.ghostfam_kin_silke or false
  if race == "ghost" and not kin_done then
    api.set_flag("ghostfam_kin_silke", true)
    api.add_hearts("ghostfam_silke", 1)
    return {
      speaker = "ghostfam_silke",
      speaker_name_key = "NPC_GHOSTFAM_SILKE",
      social = false,
      lines = {
        { id = "kin1", text_key = "DLG_GHOSTFAM_SILKE_KIN_1_1", voice_key = "voice/ghostfam_silke/kin1" },
        { id = "kin2", text_key = "DLG_GHOSTFAM_SILKE_KIN_1_2", voice_key = "voice/ghostfam_silke/kin2" },
      },
      choices = {
        { id = "thanks", text_key = "DLG_GHOSTFAM_SILKE_KIN_CHOICE_THANKS", action = "close" },
      },
    }
  end
  if part == "morgen" then
    return {
      speaker = "ghostfam_silke",
      speaker_name_key = "NPC_GHOSTFAM_SILKE",
      lines = {
        { id = "dawn", text_key = "DLG_GHOSTFAM_SILKE_DAWN_1", voice_key = "voice/ghostfam_silke/dawn" },
      },
      choices = {
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if hour >= 25 then
    return {
      speaker = "ghostfam_silke",
      speaker_name_key = "NPC_GHOSTFAM_SILKE",
      lines = {
        { id = "late2", text_key = "DLG_GHOSTFAM_SILKE_LATE_2", voice_key = "voice/ghostfam_silke/late2" },
      },
      choices = {
        { id = "ask_blund", text_key = "DLG_GHOSTFAM_SILKE_CHOICE_BLUND", action = "show_info", info_key = "DLG_GHOSTFAM_SILKE_SEEK_SLEEP" },
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if hour >= 24 then
    return {
      speaker = "ghostfam_silke",
      speaker_name_key = "NPC_GHOSTFAM_SILKE",
      lines = {
        { id = "late", text_key = "DLG_GHOSTFAM_SILKE_LATE_1", voice_key = "voice/ghostfam_silke/late" },
      },
      choices = {
        { id = "ask_blund", text_key = "DLG_GHOSTFAM_SILKE_CHOICE_BLUND", action = "show_info", info_key = "DLG_GHOSTFAM_SILKE_SEEK_SLEEP" },
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if weekday == 2 and hour >= 18 then
    return {
      speaker = "ghostfam_silke",
      speaker_name_key = "NPC_GHOSTFAM_SILKE",
      lines = {
        { id = "late", text_key = "DLG_GHOSTFAM_SILKE_LATE_1", voice_key = "voice/ghostfam_silke/late" },
      },
      choices = {
        { id = "ask_blund", text_key = "DLG_GHOSTFAM_SILKE_CHOICE_BLUND", action = "show_info", info_key = "DLG_GHOSTFAM_SILKE_SEEK_OFF" },
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if weekday == 0 and hour >= 21 then
    return {
      speaker = "ghostfam_silke",
      speaker_name_key = "NPC_GHOSTFAM_SILKE",
      lines = {
        { id = "late", text_key = "DLG_GHOSTFAM_SILKE_LATE_1", voice_key = "voice/ghostfam_silke/late" },
      },
      choices = {
        { id = "ask_blund", text_key = "DLG_GHOSTFAM_SILKE_CHOICE_BLUND", action = "show_info", info_key = "DLG_GHOSTFAM_SILKE_SEEK_0_B" },
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if weekday == 0 and hour >= 18 and race == "ghost" then
    return {
      speaker = "ghostfam_silke",
      speaker_name_key = "NPC_GHOSTFAM_SILKE",
      lines = {
        { id = "kin_greet", text_key = "DLG_GHOSTFAM_SILKE_KIN_GREET_1", voice_key = "voice/ghostfam_silke/kin_greet" },
      },
      choices = {
        { id = "ask_blund", text_key = "DLG_GHOSTFAM_SILKE_CHOICE_BLUND", action = "show_info", info_key = "DLG_GHOSTFAM_SILKE_SEEK_0_A" },
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if weekday == 0 and hour >= 18 then
    return {
      speaker = "ghostfam_silke",
      speaker_name_key = "NPC_GHOSTFAM_SILKE",
      lines = {
        { id = "greet", text_key = "DLG_GHOSTFAM_SILKE_GREET_1", voice_key = "voice/ghostfam_silke/greet" },
      },
      choices = {
        { id = "ask_blund", text_key = "DLG_GHOSTFAM_SILKE_CHOICE_BLUND", action = "show_info", info_key = "DLG_GHOSTFAM_SILKE_SEEK_0_A" },
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if weekday == 1 and hour >= 21 then
    return {
      speaker = "ghostfam_silke",
      speaker_name_key = "NPC_GHOSTFAM_SILKE",
      lines = {
        { id = "late", text_key = "DLG_GHOSTFAM_SILKE_LATE_1", voice_key = "voice/ghostfam_silke/late" },
      },
      choices = {
        { id = "ask_blund", text_key = "DLG_GHOSTFAM_SILKE_CHOICE_BLUND", action = "show_info", info_key = "DLG_GHOSTFAM_SILKE_SEEK_1_B" },
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if weekday == 1 and hour >= 18 and race == "ghost" then
    return {
      speaker = "ghostfam_silke",
      speaker_name_key = "NPC_GHOSTFAM_SILKE",
      lines = {
        { id = "kin_greet", text_key = "DLG_GHOSTFAM_SILKE_KIN_GREET_1", voice_key = "voice/ghostfam_silke/kin_greet" },
      },
      choices = {
        { id = "ask_blund", text_key = "DLG_GHOSTFAM_SILKE_CHOICE_BLUND", action = "show_info", info_key = "DLG_GHOSTFAM_SILKE_SEEK_1_A" },
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if weekday == 1 and hour >= 18 then
    return {
      speaker = "ghostfam_silke",
      speaker_name_key = "NPC_GHOSTFAM_SILKE",
      lines = {
        { id = "greet", text_key = "DLG_GHOSTFAM_SILKE_GREET_1", voice_key = "voice/ghostfam_silke/greet" },
      },
      choices = {
        { id = "ask_blund", text_key = "DLG_GHOSTFAM_SILKE_CHOICE_BLUND", action = "show_info", info_key = "DLG_GHOSTFAM_SILKE_SEEK_1_A" },
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if weekday == 3 and hour >= 21 then
    return {
      speaker = "ghostfam_silke",
      speaker_name_key = "NPC_GHOSTFAM_SILKE",
      lines = {
        { id = "late", text_key = "DLG_GHOSTFAM_SILKE_LATE_1", voice_key = "voice/ghostfam_silke/late" },
      },
      choices = {
        { id = "ask_blund", text_key = "DLG_GHOSTFAM_SILKE_CHOICE_BLUND", action = "show_info", info_key = "DLG_GHOSTFAM_SILKE_SEEK_3_B" },
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if weekday == 3 and hour >= 18 and race == "ghost" then
    return {
      speaker = "ghostfam_silke",
      speaker_name_key = "NPC_GHOSTFAM_SILKE",
      lines = {
        { id = "kin_greet", text_key = "DLG_GHOSTFAM_SILKE_KIN_GREET_1", voice_key = "voice/ghostfam_silke/kin_greet" },
      },
      choices = {
        { id = "ask_blund", text_key = "DLG_GHOSTFAM_SILKE_CHOICE_BLUND", action = "show_info", info_key = "DLG_GHOSTFAM_SILKE_SEEK_3_A" },
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if weekday == 3 and hour >= 18 then
    return {
      speaker = "ghostfam_silke",
      speaker_name_key = "NPC_GHOSTFAM_SILKE",
      lines = {
        { id = "greet", text_key = "DLG_GHOSTFAM_SILKE_GREET_1", voice_key = "voice/ghostfam_silke/greet" },
      },
      choices = {
        { id = "ask_blund", text_key = "DLG_GHOSTFAM_SILKE_CHOICE_BLUND", action = "show_info", info_key = "DLG_GHOSTFAM_SILKE_SEEK_3_A" },
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if weekday == 4 and hour >= 21 then
    return {
      speaker = "ghostfam_silke",
      speaker_name_key = "NPC_GHOSTFAM_SILKE",
      lines = {
        { id = "late", text_key = "DLG_GHOSTFAM_SILKE_LATE_1", voice_key = "voice/ghostfam_silke/late" },
      },
      choices = {
        { id = "ask_blund", text_key = "DLG_GHOSTFAM_SILKE_CHOICE_BLUND", action = "show_info", info_key = "DLG_GHOSTFAM_SILKE_SEEK_4_B" },
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if weekday == 4 and hour >= 18 and race == "ghost" then
    return {
      speaker = "ghostfam_silke",
      speaker_name_key = "NPC_GHOSTFAM_SILKE",
      lines = {
        { id = "kin_greet", text_key = "DLG_GHOSTFAM_SILKE_KIN_GREET_1", voice_key = "voice/ghostfam_silke/kin_greet" },
      },
      choices = {
        { id = "ask_blund", text_key = "DLG_GHOSTFAM_SILKE_CHOICE_BLUND", action = "show_info", info_key = "DLG_GHOSTFAM_SILKE_SEEK_4_A" },
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if weekday == 4 and hour >= 18 then
    return {
      speaker = "ghostfam_silke",
      speaker_name_key = "NPC_GHOSTFAM_SILKE",
      lines = {
        { id = "greet", text_key = "DLG_GHOSTFAM_SILKE_GREET_1", voice_key = "voice/ghostfam_silke/greet" },
      },
      choices = {
        { id = "ask_blund", text_key = "DLG_GHOSTFAM_SILKE_CHOICE_BLUND", action = "show_info", info_key = "DLG_GHOSTFAM_SILKE_SEEK_4_A" },
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if weekday == 5 and hour >= 21 then
    return {
      speaker = "ghostfam_silke",
      speaker_name_key = "NPC_GHOSTFAM_SILKE",
      lines = {
        { id = "late", text_key = "DLG_GHOSTFAM_SILKE_LATE_1", voice_key = "voice/ghostfam_silke/late" },
      },
      choices = {
        { id = "ask_blund", text_key = "DLG_GHOSTFAM_SILKE_CHOICE_BLUND", action = "show_info", info_key = "DLG_GHOSTFAM_SILKE_SEEK_5_B" },
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if weekday == 5 and hour >= 18 and race == "ghost" then
    return {
      speaker = "ghostfam_silke",
      speaker_name_key = "NPC_GHOSTFAM_SILKE",
      lines = {
        { id = "kin_greet", text_key = "DLG_GHOSTFAM_SILKE_KIN_GREET_1", voice_key = "voice/ghostfam_silke/kin_greet" },
      },
      choices = {
        { id = "ask_blund", text_key = "DLG_GHOSTFAM_SILKE_CHOICE_BLUND", action = "show_info", info_key = "DLG_GHOSTFAM_SILKE_SEEK_5_A" },
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if weekday == 5 and hour >= 18 then
    return {
      speaker = "ghostfam_silke",
      speaker_name_key = "NPC_GHOSTFAM_SILKE",
      lines = {
        { id = "greet", text_key = "DLG_GHOSTFAM_SILKE_GREET_1", voice_key = "voice/ghostfam_silke/greet" },
      },
      choices = {
        { id = "ask_blund", text_key = "DLG_GHOSTFAM_SILKE_CHOICE_BLUND", action = "show_info", info_key = "DLG_GHOSTFAM_SILKE_SEEK_5_A" },
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if weekday == 6 and hour >= 21 then
    return {
      speaker = "ghostfam_silke",
      speaker_name_key = "NPC_GHOSTFAM_SILKE",
      lines = {
        { id = "late", text_key = "DLG_GHOSTFAM_SILKE_LATE_1", voice_key = "voice/ghostfam_silke/late" },
      },
      choices = {
        { id = "ask_blund", text_key = "DLG_GHOSTFAM_SILKE_CHOICE_BLUND", action = "show_info", info_key = "DLG_GHOSTFAM_SILKE_SEEK_6_B" },
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if weekday == 6 and hour >= 18 and race == "ghost" then
    return {
      speaker = "ghostfam_silke",
      speaker_name_key = "NPC_GHOSTFAM_SILKE",
      lines = {
        { id = "kin_greet", text_key = "DLG_GHOSTFAM_SILKE_KIN_GREET_1", voice_key = "voice/ghostfam_silke/kin_greet" },
      },
      choices = {
        { id = "ask_blund", text_key = "DLG_GHOSTFAM_SILKE_CHOICE_BLUND", action = "show_info", info_key = "DLG_GHOSTFAM_SILKE_SEEK_6_A" },
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if weekday == 6 and hour >= 18 then
    return {
      speaker = "ghostfam_silke",
      speaker_name_key = "NPC_GHOSTFAM_SILKE",
      lines = {
        { id = "greet", text_key = "DLG_GHOSTFAM_SILKE_GREET_1", voice_key = "voice/ghostfam_silke/greet" },
      },
      choices = {
        { id = "ask_blund", text_key = "DLG_GHOSTFAM_SILKE_CHOICE_BLUND", action = "show_info", info_key = "DLG_GHOSTFAM_SILKE_SEEK_6_A" },
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if hour >= 17 then
    return {
      speaker = "ghostfam_silke",
      speaker_name_key = "NPC_GHOSTFAM_SILKE",
      lines = {
        { id = "greet", text_key = "DLG_GHOSTFAM_SILKE_GREET_1", voice_key = "voice/ghostfam_silke/greet" },
      },
      choices = {
        { id = "ask_blund", text_key = "DLG_GHOSTFAM_SILKE_CHOICE_BLUND", action = "show_info", info_key = "DLG_GHOSTFAM_SILKE_SEEK_WAIT" },
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if race == "ghost" then
    return {
      speaker = "ghostfam_silke",
      speaker_name_key = "NPC_GHOSTFAM_SILKE",
      lines = {
        { id = "kin_greet", text_key = "DLG_GHOSTFAM_SILKE_KIN_GREET_1", voice_key = "voice/ghostfam_silke/kin_greet" },
      },
      choices = {
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  return {
    speaker = "ghostfam_silke",
    speaker_name_key = "NPC_GHOSTFAM_SILKE",
    lines = {
      { id = "greet", text_key = "DLG_GHOSTFAM_SILKE_GREET_1", voice_key = "voice/ghostfam_silke/greet" },
    },
    choices = {
      { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
    },
  }
end
