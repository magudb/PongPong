-- tests/fixtures/lua/social_api.lua
-- The four social api functions of LuaRuntime (addendum 8.6) as content writes them: api.get_hearts(npc),
-- api.add_hearts(npc, n), api.is_birthday(npc), api.festival(). Every function returns a plain value so a test can read what
-- Lua saw. The dialogue modules of the game read hearts as `context.hearts or friend_x or 0` (see hearts_of_context).

kind = "dialogue"
id = "fixture_social_api"

function hearts_of(npc)
  return api.get_hearts(npc)
end

function bump(npc, n)
  api.add_hearts(npc, n)
  return api.get_hearts(npc)
end

function is_bday(npc)
  return api.is_birthday(npc)
end

function festival_now()
  return api.festival()
end

function festival_is_on()
  return api.festival() ~= ""
end

function stage_of(npc)
  local h = api.get_hearts(npc) or 0
  if h >= 4 then
    return "close"
  end
  return "stranger"
end

function hearts_of_context(context)
  local h = context.hearts or friend_fixture_npc or 0
  return h
end
