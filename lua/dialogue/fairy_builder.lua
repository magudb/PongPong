-- dialogue/fairy_builder.lua
-- Carpenter fairy Hasselnød (Tømrerfe Hasselnød) - builds the home upgrades and runs the builder yard.
-- Reads home_tier (1..10), home_building (target tier while under construction, else 0) and home_upgrade_done (tier just finished until acknowledged, else 0)
-- from the dialogue context, falling back to the world flag of the same name, falling back to 1 / 0 / 0.  The locals are ALWAYS numbers, because the project interpreter
-- raises a script error for  false == 3  (an unset flag compared to an int).  Branch order matters: celebration, then construction, then idle.

kind = "dialogue"
id = "fairy_builder"

function get_dialogue(context)
  local home_tier = context.home_tier or home_tier or 1
  local home_building = context.home_building or home_building or 0
  local home_upgrade_done = context.home_upgrade_done or home_upgrade_done or 0
  if home_upgrade_done == 2 then
    return {
      speaker = "fairy_builder",
      speaker_name_key = "NPC_FAIRY_BUILDER",
      lines = {
      {
        id = "t02_done",
        text_key = "DLG_BUILDER_T02_DONE",
        voice_key = "voice/fairy_builder/t02_done",
      },
      },
      choices = {
        {
          id = "materials",
          text_key = "DIALOGUE_CHOICE_OPEN_SHOP",
          action = "open_shop",
          shop_id = "builder_yard",
        },
        {
          id = "goodbye",
          text_key = "DIALOGUE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if home_upgrade_done == 3 then
    return {
      speaker = "fairy_builder",
      speaker_name_key = "NPC_FAIRY_BUILDER",
      lines = {
      {
        id = "t03_done",
        text_key = "DLG_BUILDER_T03_DONE",
        voice_key = "voice/fairy_builder/t03_done",
      },
      },
      choices = {
        {
          id = "materials",
          text_key = "DIALOGUE_CHOICE_OPEN_SHOP",
          action = "open_shop",
          shop_id = "builder_yard",
        },
        {
          id = "goodbye",
          text_key = "DIALOGUE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if home_upgrade_done == 4 then
    return {
      speaker = "fairy_builder",
      speaker_name_key = "NPC_FAIRY_BUILDER",
      lines = {
      {
        id = "t04_done",
        text_key = "DLG_BUILDER_T04_DONE",
        voice_key = "voice/fairy_builder/t04_done",
      },
      },
      choices = {
        {
          id = "materials",
          text_key = "DIALOGUE_CHOICE_OPEN_SHOP",
          action = "open_shop",
          shop_id = "builder_yard",
        },
        {
          id = "goodbye",
          text_key = "DIALOGUE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if home_upgrade_done == 5 then
    return {
      speaker = "fairy_builder",
      speaker_name_key = "NPC_FAIRY_BUILDER",
      lines = {
      {
        id = "t05_done",
        text_key = "DLG_BUILDER_T05_DONE",
        voice_key = "voice/fairy_builder/t05_done",
      },
      },
      choices = {
        {
          id = "materials",
          text_key = "DIALOGUE_CHOICE_OPEN_SHOP",
          action = "open_shop",
          shop_id = "builder_yard",
        },
        {
          id = "goodbye",
          text_key = "DIALOGUE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if home_upgrade_done == 6 then
    return {
      speaker = "fairy_builder",
      speaker_name_key = "NPC_FAIRY_BUILDER",
      lines = {
      {
        id = "t06_done",
        text_key = "DLG_BUILDER_T06_DONE",
        voice_key = "voice/fairy_builder/t06_done",
      },
      },
      choices = {
        {
          id = "materials",
          text_key = "DIALOGUE_CHOICE_OPEN_SHOP",
          action = "open_shop",
          shop_id = "builder_yard",
        },
        {
          id = "goodbye",
          text_key = "DIALOGUE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if home_upgrade_done == 7 then
    return {
      speaker = "fairy_builder",
      speaker_name_key = "NPC_FAIRY_BUILDER",
      lines = {
      {
        id = "t07_done",
        text_key = "DLG_BUILDER_T07_DONE",
        voice_key = "voice/fairy_builder/t07_done",
      },
      },
      choices = {
        {
          id = "materials",
          text_key = "DIALOGUE_CHOICE_OPEN_SHOP",
          action = "open_shop",
          shop_id = "builder_yard",
        },
        {
          id = "goodbye",
          text_key = "DIALOGUE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if home_upgrade_done == 8 then
    return {
      speaker = "fairy_builder",
      speaker_name_key = "NPC_FAIRY_BUILDER",
      lines = {
      {
        id = "t08_done",
        text_key = "DLG_BUILDER_T08_DONE",
        voice_key = "voice/fairy_builder/t08_done",
      },
      },
      choices = {
        {
          id = "materials",
          text_key = "DIALOGUE_CHOICE_OPEN_SHOP",
          action = "open_shop",
          shop_id = "builder_yard",
        },
        {
          id = "goodbye",
          text_key = "DIALOGUE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if home_upgrade_done == 9 then
    return {
      speaker = "fairy_builder",
      speaker_name_key = "NPC_FAIRY_BUILDER",
      lines = {
      {
        id = "t09_done",
        text_key = "DLG_BUILDER_T09_DONE",
        voice_key = "voice/fairy_builder/t09_done",
      },
      },
      choices = {
        {
          id = "materials",
          text_key = "DIALOGUE_CHOICE_OPEN_SHOP",
          action = "open_shop",
          shop_id = "builder_yard",
        },
        {
          id = "goodbye",
          text_key = "DIALOGUE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if home_upgrade_done == 10 then
    return {
      speaker = "fairy_builder",
      speaker_name_key = "NPC_FAIRY_BUILDER",
      lines = {
      {
        id = "t10_done",
        text_key = "DLG_BUILDER_T10_DONE",
        voice_key = "voice/fairy_builder/t10_done",
      },
      },
      choices = {
        {
          id = "materials",
          text_key = "DIALOGUE_CHOICE_OPEN_SHOP",
          action = "open_shop",
          shop_id = "builder_yard",
        },
        {
          id = "goodbye",
          text_key = "DIALOGUE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if home_building == 2 then
    return {
      speaker = "fairy_builder",
      speaker_name_key = "NPC_FAIRY_BUILDER",
      lines = {
      {
        id = "t02_building",
        text_key = "DLG_BUILDER_T02_BUILDING",
        voice_key = "voice/fairy_builder/t02_building",
      },
      },
      choices = {
        {
          id = "materials",
          text_key = "DIALOGUE_CHOICE_OPEN_SHOP",
          action = "open_shop",
          shop_id = "builder_yard",
        },
        {
          id = "goodbye",
          text_key = "DIALOGUE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if home_building == 3 then
    return {
      speaker = "fairy_builder",
      speaker_name_key = "NPC_FAIRY_BUILDER",
      lines = {
      {
        id = "t03_building",
        text_key = "DLG_BUILDER_T03_BUILDING",
        voice_key = "voice/fairy_builder/t03_building",
      },
      },
      choices = {
        {
          id = "materials",
          text_key = "DIALOGUE_CHOICE_OPEN_SHOP",
          action = "open_shop",
          shop_id = "builder_yard",
        },
        {
          id = "goodbye",
          text_key = "DIALOGUE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if home_building == 4 then
    return {
      speaker = "fairy_builder",
      speaker_name_key = "NPC_FAIRY_BUILDER",
      lines = {
      {
        id = "t04_building",
        text_key = "DLG_BUILDER_T04_BUILDING",
        voice_key = "voice/fairy_builder/t04_building",
      },
      },
      choices = {
        {
          id = "materials",
          text_key = "DIALOGUE_CHOICE_OPEN_SHOP",
          action = "open_shop",
          shop_id = "builder_yard",
        },
        {
          id = "goodbye",
          text_key = "DIALOGUE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if home_building == 5 then
    return {
      speaker = "fairy_builder",
      speaker_name_key = "NPC_FAIRY_BUILDER",
      lines = {
      {
        id = "t05_building",
        text_key = "DLG_BUILDER_T05_BUILDING",
        voice_key = "voice/fairy_builder/t05_building",
      },
      },
      choices = {
        {
          id = "materials",
          text_key = "DIALOGUE_CHOICE_OPEN_SHOP",
          action = "open_shop",
          shop_id = "builder_yard",
        },
        {
          id = "goodbye",
          text_key = "DIALOGUE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if home_building == 6 then
    return {
      speaker = "fairy_builder",
      speaker_name_key = "NPC_FAIRY_BUILDER",
      lines = {
      {
        id = "t06_building",
        text_key = "DLG_BUILDER_T06_BUILDING",
        voice_key = "voice/fairy_builder/t06_building",
      },
      },
      choices = {
        {
          id = "materials",
          text_key = "DIALOGUE_CHOICE_OPEN_SHOP",
          action = "open_shop",
          shop_id = "builder_yard",
        },
        {
          id = "goodbye",
          text_key = "DIALOGUE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if home_building == 7 then
    return {
      speaker = "fairy_builder",
      speaker_name_key = "NPC_FAIRY_BUILDER",
      lines = {
      {
        id = "t07_building",
        text_key = "DLG_BUILDER_T07_BUILDING",
        voice_key = "voice/fairy_builder/t07_building",
      },
      },
      choices = {
        {
          id = "materials",
          text_key = "DIALOGUE_CHOICE_OPEN_SHOP",
          action = "open_shop",
          shop_id = "builder_yard",
        },
        {
          id = "goodbye",
          text_key = "DIALOGUE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if home_building == 8 then
    return {
      speaker = "fairy_builder",
      speaker_name_key = "NPC_FAIRY_BUILDER",
      lines = {
      {
        id = "t08_building",
        text_key = "DLG_BUILDER_T08_BUILDING",
        voice_key = "voice/fairy_builder/t08_building",
      },
      },
      choices = {
        {
          id = "materials",
          text_key = "DIALOGUE_CHOICE_OPEN_SHOP",
          action = "open_shop",
          shop_id = "builder_yard",
        },
        {
          id = "goodbye",
          text_key = "DIALOGUE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if home_building == 9 then
    return {
      speaker = "fairy_builder",
      speaker_name_key = "NPC_FAIRY_BUILDER",
      lines = {
      {
        id = "t09_building",
        text_key = "DLG_BUILDER_T09_BUILDING",
        voice_key = "voice/fairy_builder/t09_building",
      },
      },
      choices = {
        {
          id = "materials",
          text_key = "DIALOGUE_CHOICE_OPEN_SHOP",
          action = "open_shop",
          shop_id = "builder_yard",
        },
        {
          id = "goodbye",
          text_key = "DIALOGUE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if home_building == 10 then
    return {
      speaker = "fairy_builder",
      speaker_name_key = "NPC_FAIRY_BUILDER",
      lines = {
      {
        id = "t10_building",
        text_key = "DLG_BUILDER_T10_BUILDING",
        voice_key = "voice/fairy_builder/t10_building",
      },
      },
      choices = {
        {
          id = "materials",
          text_key = "DIALOGUE_CHOICE_OPEN_SHOP",
          action = "open_shop",
          shop_id = "builder_yard",
        },
        {
          id = "goodbye",
          text_key = "DIALOGUE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if home_tier == 1 then
    return {
      speaker = "fairy_builder",
      speaker_name_key = "NPC_FAIRY_BUILDER",
      lines = {
      {
        id = "t01_idle",
        text_key = "DLG_BUILDER_T01_IDLE",
        voice_key = "voice/fairy_builder/t01_idle",
      },
      {
        id = "t01_offer",
        text_key = "DLG_BUILDER_T01_OFFER",
        voice_key = "voice/fairy_builder/t01_offer",
      },
      },
      choices = {
        {
          id = "upgrade",
          text_key = "DLG_CHOICE_HOME_UPGRADE",
          action = "home_upgrade",
          tier = 2,
        },
        {
          id = "materials",
          text_key = "DIALOGUE_CHOICE_OPEN_SHOP",
          action = "open_shop",
          shop_id = "builder_yard",
        },
        {
          id = "goodbye",
          text_key = "DIALOGUE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if home_tier == 2 then
    return {
      speaker = "fairy_builder",
      speaker_name_key = "NPC_FAIRY_BUILDER",
      lines = {
      {
        id = "t02_idle",
        text_key = "DLG_BUILDER_T02_IDLE",
        voice_key = "voice/fairy_builder/t02_idle",
      },
      {
        id = "t02_offer",
        text_key = "DLG_BUILDER_T02_OFFER",
        voice_key = "voice/fairy_builder/t02_offer",
      },
      },
      choices = {
        {
          id = "upgrade",
          text_key = "DLG_CHOICE_HOME_UPGRADE",
          action = "home_upgrade",
          tier = 3,
        },
        {
          id = "materials",
          text_key = "DIALOGUE_CHOICE_OPEN_SHOP",
          action = "open_shop",
          shop_id = "builder_yard",
        },
        {
          id = "goodbye",
          text_key = "DIALOGUE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if home_tier == 3 then
    return {
      speaker = "fairy_builder",
      speaker_name_key = "NPC_FAIRY_BUILDER",
      lines = {
      {
        id = "t03_idle",
        text_key = "DLG_BUILDER_T03_IDLE",
        voice_key = "voice/fairy_builder/t03_idle",
      },
      {
        id = "t03_offer",
        text_key = "DLG_BUILDER_T03_OFFER",
        voice_key = "voice/fairy_builder/t03_offer",
      },
      },
      choices = {
        {
          id = "upgrade",
          text_key = "DLG_CHOICE_HOME_UPGRADE",
          action = "home_upgrade",
          tier = 4,
        },
        {
          id = "materials",
          text_key = "DIALOGUE_CHOICE_OPEN_SHOP",
          action = "open_shop",
          shop_id = "builder_yard",
        },
        {
          id = "goodbye",
          text_key = "DIALOGUE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if home_tier == 4 then
    return {
      speaker = "fairy_builder",
      speaker_name_key = "NPC_FAIRY_BUILDER",
      lines = {
      {
        id = "t04_idle",
        text_key = "DLG_BUILDER_T04_IDLE",
        voice_key = "voice/fairy_builder/t04_idle",
      },
      {
        id = "t04_offer",
        text_key = "DLG_BUILDER_T04_OFFER",
        voice_key = "voice/fairy_builder/t04_offer",
      },
      },
      choices = {
        {
          id = "upgrade",
          text_key = "DLG_CHOICE_HOME_UPGRADE",
          action = "home_upgrade",
          tier = 5,
        },
        {
          id = "materials",
          text_key = "DIALOGUE_CHOICE_OPEN_SHOP",
          action = "open_shop",
          shop_id = "builder_yard",
        },
        {
          id = "goodbye",
          text_key = "DIALOGUE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if home_tier == 5 then
    return {
      speaker = "fairy_builder",
      speaker_name_key = "NPC_FAIRY_BUILDER",
      lines = {
      {
        id = "t05_idle",
        text_key = "DLG_BUILDER_T05_IDLE",
        voice_key = "voice/fairy_builder/t05_idle",
      },
      {
        id = "t05_offer",
        text_key = "DLG_BUILDER_T05_OFFER",
        voice_key = "voice/fairy_builder/t05_offer",
      },
      },
      choices = {
        {
          id = "upgrade",
          text_key = "DLG_CHOICE_HOME_UPGRADE",
          action = "home_upgrade",
          tier = 6,
        },
        {
          id = "materials",
          text_key = "DIALOGUE_CHOICE_OPEN_SHOP",
          action = "open_shop",
          shop_id = "builder_yard",
        },
        {
          id = "goodbye",
          text_key = "DIALOGUE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if home_tier == 6 then
    return {
      speaker = "fairy_builder",
      speaker_name_key = "NPC_FAIRY_BUILDER",
      lines = {
      {
        id = "t06_idle",
        text_key = "DLG_BUILDER_T06_IDLE",
        voice_key = "voice/fairy_builder/t06_idle",
      },
      {
        id = "t06_offer",
        text_key = "DLG_BUILDER_T06_OFFER",
        voice_key = "voice/fairy_builder/t06_offer",
      },
      },
      choices = {
        {
          id = "upgrade",
          text_key = "DLG_CHOICE_HOME_UPGRADE",
          action = "home_upgrade",
          tier = 7,
        },
        {
          id = "materials",
          text_key = "DIALOGUE_CHOICE_OPEN_SHOP",
          action = "open_shop",
          shop_id = "builder_yard",
        },
        {
          id = "goodbye",
          text_key = "DIALOGUE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if home_tier == 7 then
    return {
      speaker = "fairy_builder",
      speaker_name_key = "NPC_FAIRY_BUILDER",
      lines = {
      {
        id = "t07_idle",
        text_key = "DLG_BUILDER_T07_IDLE",
        voice_key = "voice/fairy_builder/t07_idle",
      },
      {
        id = "t07_offer",
        text_key = "DLG_BUILDER_T07_OFFER",
        voice_key = "voice/fairy_builder/t07_offer",
      },
      },
      choices = {
        {
          id = "upgrade",
          text_key = "DLG_CHOICE_HOME_UPGRADE",
          action = "home_upgrade",
          tier = 8,
        },
        {
          id = "materials",
          text_key = "DIALOGUE_CHOICE_OPEN_SHOP",
          action = "open_shop",
          shop_id = "builder_yard",
        },
        {
          id = "goodbye",
          text_key = "DIALOGUE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if home_tier == 8 then
    return {
      speaker = "fairy_builder",
      speaker_name_key = "NPC_FAIRY_BUILDER",
      lines = {
      {
        id = "t08_idle",
        text_key = "DLG_BUILDER_T08_IDLE",
        voice_key = "voice/fairy_builder/t08_idle",
      },
      {
        id = "t08_offer",
        text_key = "DLG_BUILDER_T08_OFFER",
        voice_key = "voice/fairy_builder/t08_offer",
      },
      },
      choices = {
        {
          id = "upgrade",
          text_key = "DLG_CHOICE_HOME_UPGRADE",
          action = "home_upgrade",
          tier = 9,
        },
        {
          id = "materials",
          text_key = "DIALOGUE_CHOICE_OPEN_SHOP",
          action = "open_shop",
          shop_id = "builder_yard",
        },
        {
          id = "goodbye",
          text_key = "DIALOGUE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if home_tier == 9 then
    return {
      speaker = "fairy_builder",
      speaker_name_key = "NPC_FAIRY_BUILDER",
      lines = {
      {
        id = "t09_idle",
        text_key = "DLG_BUILDER_T09_IDLE",
        voice_key = "voice/fairy_builder/t09_idle",
      },
      {
        id = "t09_offer",
        text_key = "DLG_BUILDER_T09_OFFER",
        voice_key = "voice/fairy_builder/t09_offer",
      },
      },
      choices = {
        {
          id = "upgrade",
          text_key = "DLG_CHOICE_HOME_UPGRADE",
          action = "home_upgrade",
          tier = 10,
        },
        {
          id = "materials",
          text_key = "DIALOGUE_CHOICE_OPEN_SHOP",
          action = "open_shop",
          shop_id = "builder_yard",
        },
        {
          id = "goodbye",
          text_key = "DIALOGUE_CHOICE_GOODBYE",
          action = "close",
        },
      },
    }
  end
  if home_tier == 10 then
    return {
      speaker = "fairy_builder",
      speaker_name_key = "NPC_FAIRY_BUILDER",
      lines = {
      {
        id = "t10_idle",
        text_key = "DLG_BUILDER_T10_IDLE",
        voice_key = "voice/fairy_builder/t10_idle",
      },
      },
      choices = {
        {
          id = "materials",
          text_key = "DIALOGUE_CHOICE_OPEN_SHOP",
          action = "open_shop",
          shop_id = "builder_yard",
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
    speaker = "fairy_builder",
    speaker_name_key = "NPC_FAIRY_BUILDER",
    lines = {
      {
        id = "t01_idle",
        text_key = "DLG_BUILDER_T01_IDLE",
        voice_key = "voice/fairy_builder/t01_idle",
      },
      {
        id = "t01_offer",
        text_key = "DLG_BUILDER_T01_OFFER",
        voice_key = "voice/fairy_builder/t01_offer",
      },
    },
    choices = {
        {
          id = "upgrade",
          text_key = "DLG_CHOICE_HOME_UPGRADE",
          action = "home_upgrade",
          tier = 2,
        },
        {
          id = "materials",
          text_key = "DIALOGUE_CHOICE_OPEN_SHOP",
          action = "open_shop",
          shop_id = "builder_yard",
        },
        {
          id = "goodbye",
          text_key = "DIALOGUE_CHOICE_GOODBYE",
          action = "close",
        },
    },
  }
end
