-- tests/fixtures/lua/lint_bad_rarity.lua
-- `epic` is not on the rarity ladder: LuaRuntime reports it in lint_report (rule `rarity`) when the file is loaded.

kind = "items"

items = {
  fixture_epic_thing = {
    name_key = "ITEM_FIXTURE_EPIC_THING",
    category = "special",
    rarity = "epic",
  },
}
