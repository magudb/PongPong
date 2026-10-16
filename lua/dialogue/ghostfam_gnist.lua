-- dialogue/ghostfam_gnist.lua
-- Far Gnist - the tall father, a lantern maker: keeps Natlys' Lygtehus (shop id lantern_house, 17:00-01:00 = game hours 17..25, closed Wednesday); the shop choice is shown (open_shop) only while the shop is open by the same hours; a ghost hero is his wife's sibling's child: the first meeting is a short scene with two bottles of oil.
-- The social layer (S-talk DialogueBridge.decorate) prepends the first-meeting / daily greeting line and appends 'Giv en gave' / 'Fortæl mig om dig' before the close choice
-- (NOT for a scene that returns `social = false`: the cousin's first meeting is such a scene; the finished conversation still counts as met and pays the weekly heart: N04 task 3 / S-talk task 2).
-- Context (P14 task 3): race animal|fairy|hobbit|ghost, hero = the look id, daypart, weekday (0 = Monday) and hour = the STORED game hour 6..25 (24 and 25 are 00:xx and 01:xx of the SAME game day, CLOCK_26),
-- plus every world flag.  The cousin's flags (all JSON-safe bools): ghostfam_kin_<name> (first meeting done) and ghostfam_kin_look_<name> (the look remark said once).  Only unsupported-token-free Lua
-- (no else / elseif / loops): the branches are early returns.

kind = "dialogue"
id = "ghostfam_gnist"

function get_dialogue(context)
  local race = context.race or ""
  local hero = context.hero or ""
  local part = context.daypart or ""
  local hour = context.hour or 0
  local weekday = context.weekday or 0
  local kin_done = context.ghostfam_kin_gnist or false
  local opens_at = context.shop_opens_at or 17
  local closes_at = context.shop_closes_at or 25
  local closed_reason = context.shop_closed_reason or ""
  local closed_today = (weekday == 2) or (closed_reason == "festival") or (hour >= closes_at)
  local too_early = (not closed_today) and (hour < opens_at)
  if race == "ghost" and not kin_done then
    api.set_flag("ghostfam_kin_gnist", true)
    api.add_hearts("ghostfam_gnist", 1)
    api.add_item("lantern_oil", 2)
    return {
      speaker = "ghostfam_gnist",
      speaker_name_key = "NPC_GHOSTFAM_GNIST",
      social = false,
      lines = {
        { id = "kin1", text_key = "DLG_GHOSTFAM_GNIST_KIN_1_1", voice_key = "voice/ghostfam_gnist/kin1" },
        { id = "kin2", text_key = "DLG_GHOSTFAM_GNIST_KIN_1_2", voice_key = "voice/ghostfam_gnist/kin2" },
      },
      choices = {
        { id = "thanks", text_key = "DLG_GHOSTFAM_GNIST_KIN_CHOICE_THANKS", action = "close" },
      },
    }
  end
  if weekday == 2 then
    return {
      speaker = "ghostfam_gnist",
      speaker_name_key = "NPC_GHOSTFAM_GNIST",
      lines = {
        { id = "closed", text_key = "DLG_GHOSTFAM_GNIST_CLOSED_1", voice_key = "voice/ghostfam_gnist/closed" },
      },
      choices = {
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if hour >= closes_at then
    return {
      speaker = "ghostfam_gnist",
      speaker_name_key = "NPC_GHOSTFAM_GNIST",
      lines = {
        { id = "closed_night", text_key = "DLG_GHOSTFAM_GNIST_CLOSED_NIGHT_1", voice_key = "voice/ghostfam_gnist/closed_night" },
      },
      choices = {
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if too_early then
    return {
      speaker = "ghostfam_gnist",
      speaker_name_key = "NPC_GHOSTFAM_GNIST",
      lines = {
        { id = "early", text_key = "DLG_GHOSTFAM_GNIST_EARLY_1", voice_key = "voice/ghostfam_gnist/early" },
      },
      choices = {
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  if race == "ghost" then
    return {
      speaker = "ghostfam_gnist",
      speaker_name_key = "NPC_GHOSTFAM_GNIST",
      lines = {
        { id = "kin_greet", text_key = "DLG_GHOSTFAM_GNIST_KIN_GREET_1", voice_key = "voice/ghostfam_gnist/kin_greet" },
      },
      choices = {
        { id = "shop", text_key = "DLG_GHOSTFAM_GNIST_CHOICE_SHOP", action = "open_shop", shop_id = "lantern_house" },
        { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
      },
    }
  end
  return {
    speaker = "ghostfam_gnist",
    speaker_name_key = "NPC_GHOSTFAM_GNIST",
    lines = {
      { id = "greet", text_key = "DLG_GHOSTFAM_GNIST_GREET_1", voice_key = "voice/ghostfam_gnist/greet" },
    },
    choices = {
      { id = "shop", text_key = "DLG_GHOSTFAM_GNIST_CHOICE_SHOP", action = "open_shop", shop_id = "lantern_house" },
      { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
    },
  }
end
