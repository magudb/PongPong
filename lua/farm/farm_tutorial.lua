-- config/farm_tutorial.lua  (package N04; real path lua/farm/farm_tutorial.lua)
-- The first morning on the farm as DATA. TutorialRunner (scripts/farm/steading/tutorial/tutorial_runner.gd) plays `first_morning` once on a
-- new game (called by IntroSequence) and shows the `hints` as whispers while the quest forste_dage is active. A designer adds a step or a hint
-- here and in farm_tutorial.csv; no code changes. Ids in `npc` / `post` / `spawn` / `quest` / `dialogue` are checked by tutorial_check.py and
-- by farm_first_morning.references_resolve.
-- step kinds: npc_enter {npc, post} | dialogue {id | npc+context} | npc_leave {npc, to = "warp" | "post"} | quest_accept {quest} | hint {id} | wait {seconds}
kind = "config"

config = {
  farm_tutorial = {
    first_morning = {
      -- false = the P14 letter-only flow runs unchanged (compatibility fixtures can set this through GameManager.set_config_override)
      enabled = true,
      hour = 6,
      steps = {
        { kind = "npc_enter", npc = "postman_pip", post = "pip_mailbox" },
        { kind = "dialogue", id = "farm_intro_pip" },
        { kind = "dialogue", npc = "fairy_king", context = "intro" },
        { kind = "quest_accept", quest = "intro_lottery" },
        { kind = "quest_accept", quest = "forste_dage" },
        { kind = "dialogue", id = "farm_intro_pip_bye" },
        { kind = "npc_leave", npc = "postman_pip", to = "warp" },
        { kind = "hint", id = "hoe" },
      },
    },
    -- hints: shown at most once per save (flag tut_hint_<id>), only while forste_dage is active, one at a time (>= 12 s apart)
    hints = {
      { id = "hoe", key = "TUT_HINT_HOE", glyph = "slot_1", format_actions = { "slot_1", "use_tool" }, format_action_groups_gamepad = { { "hotbar_previous", "hotbar_next" }, { "use_tool" } }, on = "step_done" },
      { id = "seeds", key = "TUT_HINT_SEEDS", glyph = "slot_7", format_actions = { "slot_7", "use_tool" }, format_action_groups_gamepad = { { "hotbar_previous", "hotbar_next" }, { "use_tool" } }, on = "game_event", event = "plot_tilled" },
      { id = "can", key = "TUT_HINT_CAN", glyph = "slot_2", format_action_groups_gamepad = { { "hotbar_previous", "hotbar_next" } }, on = "crop_planted" },
      { id = "harvest", key = "TUT_HINT_HARVEST", glyph = "interact", on = "crop_ready" },
      { id = "bin", key = "TUT_HINT_BIN", glyph = "interact", on = "crop_harvested" },
      { id = "energy", key = "TUT_HINT_ENERGY", glyph = "", on = "energy_low" },
      { id = "bridge", key = "TUT_HINT_BRIDGE", glyph = "", on = "near_warp" },
      { id = "bed", key = "TUT_HINT_BED", glyph = "interact", on = "hour_at_least", hour = 18 },
      { id = "mail", key = "TUT_HINT_MAIL", glyph = "interact", on = "day_at_least", day = 2 },
      { id = "expand", key = "TUT_HINT_EXPAND", glyph = "interact", on = "gold_at_least", gold = 800, day = 3 },
    },
  },
}
