-- tests/fixtures/lua/flag_identifiers.lua
-- INLINE fixture (RV-P2a): the same `context.x or x or default` pattern as the content dialogue lua/dialogue/fairy_builder.lua,
-- with its 29 branch combinations: done 2..10 (9) + building 2..10 (9) + tier 1..10 (10) + the fall-through default (1).
-- A bare identifier that is not a local reads the WORLD FLAG of that name; the locals are always numbers because a
-- comparison of an unset flag with a number must never raise.  The REAL fairy_builder.lua is F1's (content_features, wave 3).

kind = "dialogue"
id = "flag_identifiers"

function get_dialogue(context)
  local home_tier = context.home_tier or home_tier or 1
  local home_building = context.home_building or home_building or 0
  local home_upgrade_done = context.home_upgrade_done or home_upgrade_done or 0
  if home_upgrade_done == 2 then
    return {
      speaker = "fixture",
      branch = "done_2",
      lines = {
        { id = "t02_done", text_key = "FIXTURE_DONE_2" },
      },
      choices = {
        { id = "materials", action = "open_shop", shop_id = "builder_yard" },
        { id = "goodbye", action = "close" },
      },
    }
  end
  if home_upgrade_done == 3 then
    return {
      speaker = "fixture",
      branch = "done_3",
      lines = {
        { id = "t03_done", text_key = "FIXTURE_DONE_3" },
      },
      choices = {
        { id = "materials", action = "open_shop", shop_id = "builder_yard" },
        { id = "goodbye", action = "close" },
      },
    }
  end
  if home_upgrade_done == 4 then
    return {
      speaker = "fixture",
      branch = "done_4",
      lines = {
        { id = "t04_done", text_key = "FIXTURE_DONE_4" },
      },
      choices = {
        { id = "materials", action = "open_shop", shop_id = "builder_yard" },
        { id = "goodbye", action = "close" },
      },
    }
  end
  if home_upgrade_done == 5 then
    return {
      speaker = "fixture",
      branch = "done_5",
      lines = {
        { id = "t05_done", text_key = "FIXTURE_DONE_5" },
      },
      choices = {
        { id = "materials", action = "open_shop", shop_id = "builder_yard" },
        { id = "goodbye", action = "close" },
      },
    }
  end
  if home_upgrade_done == 6 then
    return {
      speaker = "fixture",
      branch = "done_6",
      lines = {
        { id = "t06_done", text_key = "FIXTURE_DONE_6" },
      },
      choices = {
        { id = "materials", action = "open_shop", shop_id = "builder_yard" },
        { id = "goodbye", action = "close" },
      },
    }
  end
  if home_upgrade_done == 7 then
    return {
      speaker = "fixture",
      branch = "done_7",
      lines = {
        { id = "t07_done", text_key = "FIXTURE_DONE_7" },
      },
      choices = {
        { id = "materials", action = "open_shop", shop_id = "builder_yard" },
        { id = "goodbye", action = "close" },
      },
    }
  end
  if home_upgrade_done == 8 then
    return {
      speaker = "fixture",
      branch = "done_8",
      lines = {
        { id = "t08_done", text_key = "FIXTURE_DONE_8" },
      },
      choices = {
        { id = "materials", action = "open_shop", shop_id = "builder_yard" },
        { id = "goodbye", action = "close" },
      },
    }
  end
  if home_upgrade_done == 9 then
    return {
      speaker = "fixture",
      branch = "done_9",
      lines = {
        { id = "t09_done", text_key = "FIXTURE_DONE_9" },
      },
      choices = {
        { id = "materials", action = "open_shop", shop_id = "builder_yard" },
        { id = "goodbye", action = "close" },
      },
    }
  end
  if home_upgrade_done == 10 then
    return {
      speaker = "fixture",
      branch = "done_10",
      lines = {
        { id = "t10_done", text_key = "FIXTURE_DONE_10" },
      },
      choices = {
        { id = "materials", action = "open_shop", shop_id = "builder_yard" },
        { id = "goodbye", action = "close" },
      },
    }
  end
  if home_building == 2 then
    return { speaker = "fixture", branch = "building_2", lines = { { id = "t02_building" } } }
  end
  if home_building == 3 then
    return { speaker = "fixture", branch = "building_3", lines = { { id = "t03_building" } } }
  end
  if home_building == 4 then
    return { speaker = "fixture", branch = "building_4", lines = { { id = "t04_building" } } }
  end
  if home_building == 5 then
    return { speaker = "fixture", branch = "building_5", lines = { { id = "t05_building" } } }
  end
  if home_building == 6 then
    return { speaker = "fixture", branch = "building_6", lines = { { id = "t06_building" } } }
  end
  if home_building == 7 then
    return { speaker = "fixture", branch = "building_7", lines = { { id = "t07_building" } } }
  end
  if home_building == 8 then
    return { speaker = "fixture", branch = "building_8", lines = { { id = "t08_building" } } }
  end
  if home_building == 9 then
    return { speaker = "fixture", branch = "building_9", lines = { { id = "t09_building" } } }
  end
  if home_building == 10 then
    return { speaker = "fixture", branch = "building_10", lines = { { id = "t10_building" } } }
  end
  if home_tier == 1 then
    return { speaker = "fixture", branch = "tier_1", lines = { { id = "t01_idle" }, { id = "t01_offer" } }, choices = { { id = "upgrade", action = "home_upgrade", tier = 2 } } }
  end
  if home_tier == 2 then
    return { speaker = "fixture", branch = "tier_2", lines = { { id = "t02_idle" }, { id = "t02_offer" } }, choices = { { id = "upgrade", action = "home_upgrade", tier = 3 } } }
  end
  if home_tier == 3 then
    return { speaker = "fixture", branch = "tier_3", lines = { { id = "t03_idle" }, { id = "t03_offer" } }, choices = { { id = "upgrade", action = "home_upgrade", tier = 4 } } }
  end
  if home_tier == 4 then
    return { speaker = "fixture", branch = "tier_4", lines = { { id = "t04_idle" }, { id = "t04_offer" } }, choices = { { id = "upgrade", action = "home_upgrade", tier = 5 } } }
  end
  if home_tier == 5 then
    return { speaker = "fixture", branch = "tier_5", lines = { { id = "t05_idle" }, { id = "t05_offer" } }, choices = { { id = "upgrade", action = "home_upgrade", tier = 6 } } }
  end
  if home_tier == 6 then
    return { speaker = "fixture", branch = "tier_6", lines = { { id = "t06_idle" }, { id = "t06_offer" } }, choices = { { id = "upgrade", action = "home_upgrade", tier = 7 } } }
  end
  if home_tier == 7 then
    return { speaker = "fixture", branch = "tier_7", lines = { { id = "t07_idle" }, { id = "t07_offer" } }, choices = { { id = "upgrade", action = "home_upgrade", tier = 8 } } }
  end
  if home_tier == 8 then
    return { speaker = "fixture", branch = "tier_8", lines = { { id = "t08_idle" }, { id = "t08_offer" } }, choices = { { id = "upgrade", action = "home_upgrade", tier = 9 } } }
  end
  if home_tier == 9 then
    return { speaker = "fixture", branch = "tier_9", lines = { { id = "t09_idle" }, { id = "t09_offer" } }, choices = { { id = "upgrade", action = "home_upgrade", tier = 10 } } }
  end
  if home_tier == 10 then
    return { speaker = "fixture", branch = "tier_10", lines = { { id = "t10_idle" }, { id = "t10_offer" } }, choices = { { id = "upgrade", action = "home_upgrade", tier = 11 } } }
  end
  return { speaker = "fixture", branch = "default", lines = { { id = "fallthrough" } } }
end
