-- dialogue/ghostfam_blund.lua
-- Lille Blund - the small child: a striped scarf; hides in two places every evening (the routine's weekday plan: lua/routines/ghostfam/ghostfam_blund.lua, slots in lua/config/ghostfam_seek.lua), falls asleep on the porch after midnight; a ghost hero is Blund's cousin.  GF-seek (wave 6) adds the 'found' branch (flag ghostfam_seek_found_now) as a fix-round of this file.
-- The social layer (S-talk DialogueBridge.decorate) prepends the first-meeting / daily greeting line and appends 'Giv en gave' / 'Fortæl mig om dig' before the close choice
-- (NOT for a scene that returns `social = false`: the cousin's first meeting is such a scene; the finished conversation still counts as met and pays the weekly heart: N04 task 3 / S-talk task 2).
-- Context (P14 task 3): race animal|fairy|hobbit|ghost, hero = the look id, daypart, weekday (0 = Monday) and hour = the STORED game hour 6..25 (24 and 25 are 00:xx and 01:xx of the SAME game day, CLOCK_26),
-- plus every world flag.  The cousin's flags (all JSON-safe bools): ghostfam_kin_<name> (first meeting done) and ghostfam_kin_look_<name> (the look remark said once).  Only unsupported-token-free Lua
-- (no else / elseif / loops): the branches are early returns.

kind = "dialogue"
id = "ghostfam_blund"

function get_dialogue(context)
  local race = context.race or ""
  local hero = context.hero or ""
  local part = context.daypart or ""
  local hour = context.hour or 0
  local weekday = context.weekday or 0
  local kin_done = context.ghostfam_kin_blund or false
  local look_done = context.ghostfam_kin_look_blund or false
  if race == "ghost" and not kin_done then
    api.set_flag("ghostfam_kin_blund", true)
    api.add_hearts("ghostfam_blund", 2)
    return {
      speaker = "ghostfam_blund",
      speaker_name_key = "NPC_GHOSTFAM_BLUND",
      social = false,
      lines = {
        { id = "kin1", text_key = "DLG_GHOSTFAM_BLUND_KIN_1_1", voice_key = "voice/ghostfam_blund/kin1" },
        { id = "kin2", text_key = "DLG_GHOSTFAM_BLUND_KIN_1_2", voice_key = "voice/ghostfam_blund/kin2" },
        { id = "kin3", text_key = "DLG_GHOSTFAM_BLUND_KIN_1_3", voice_key = "voice/ghostfam_blund/kin3" },
      },
      choices = {
        { id = "thanks", text_key = "DLG_GHOSTFAM_BLUND_KIN_CHOICE_THANKS", action = "close" },
      },
    }
  end
  if hour >= 25 then
    return {
      speaker = "ghostfam_blund",
      speaker_name_key = "NPC_GHOSTFAM_BLUND",
      lines = {
        { id = "sleep", text_key = "DLG_GHOSTFAM_BLUND_SLEEP_1", voice_key = "voice/ghostfam_blund/sleep" },
      },
      choices = {
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if hour >= 24 then
    return {
      speaker = "ghostfam_blund",
      speaker_name_key = "NPC_GHOSTFAM_BLUND",
      lines = {
        { id = "bed", text_key = "DLG_GHOSTFAM_BLUND_BED_1", voice_key = "voice/ghostfam_blund/bed" },
      },
      choices = {
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if part == "morgen" then
    return {
      speaker = "ghostfam_blund",
      speaker_name_key = "NPC_GHOSTFAM_BLUND",
      lines = {
        { id = "dawn", text_key = "DLG_GHOSTFAM_BLUND_DAWN_1", voice_key = "voice/ghostfam_blund/dawn" },
      },
      choices = {
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if weekday == 2 and hour >= 17 then
    return {
      speaker = "ghostfam_blund",
      speaker_name_key = "NPC_GHOSTFAM_BLUND",
      lines = {
        { id = "family", text_key = "DLG_GHOSTFAM_BLUND_FAMILY_1", voice_key = "voice/ghostfam_blund/family" },
      },
      choices = {
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if race == "ghost" and hero == "bu" and not look_done then
    api.set_flag("ghostfam_kin_look_blund", true)
    return {
      speaker = "ghostfam_blund",
      speaker_name_key = "NPC_GHOSTFAM_BLUND",
      lines = {
        { id = "kin_greet", text_key = "DLG_GHOSTFAM_BLUND_KIN_GREET_1", voice_key = "voice/ghostfam_blund/kin_greet" },
        { id = "kin_look", text_key = "DLG_GHOSTFAM_BLUND_KIN_LOOK_BU_1", voice_key = "voice/ghostfam_blund/kin_look" },
      },
      choices = {
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if race == "ghost" and hero == "hviske" and not look_done then
    api.set_flag("ghostfam_kin_look_blund", true)
    return {
      speaker = "ghostfam_blund",
      speaker_name_key = "NPC_GHOSTFAM_BLUND",
      lines = {
        { id = "kin_greet", text_key = "DLG_GHOSTFAM_BLUND_KIN_GREET_1", voice_key = "voice/ghostfam_blund/kin_greet" },
        { id = "kin_look", text_key = "DLG_GHOSTFAM_BLUND_KIN_LOOK_HVISKE_1", voice_key = "voice/ghostfam_blund/kin_look" },
      },
      choices = {
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if race == "ghost" then
    return {
      speaker = "ghostfam_blund",
      speaker_name_key = "NPC_GHOSTFAM_BLUND",
      lines = {
        { id = "kin_greet", text_key = "DLG_GHOSTFAM_BLUND_KIN_GREET_1", voice_key = "voice/ghostfam_blund/kin_greet" },
      },
      choices = {
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  return {
    speaker = "ghostfam_blund",
    speaker_name_key = "NPC_GHOSTFAM_BLUND",
    lines = {
      { id = "greet", text_key = "DLG_GHOSTFAM_BLUND_GREET_1", voice_key = "voice/ghostfam_blund/greet" },
    },
    choices = {
      { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
    },
  }
end
