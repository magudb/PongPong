-- tools/lua/ref_ser.lua: tiny JSON serializer for the reference generator (global `ser`).
-- Empty tables and tables with only numeric keys become JSON arrays, everything else an object with sorted keys.
function is_array(t)
  for k in pairs(t) do
    if type(k) ~= "number" then return false end
  end
  return true
end

function esc(s)
  return '"' .. s:gsub('[%c"\\]', function(c)
    local m = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\t'] = '\\t', ['\r'] = '\\r' }
    return m[c] or string.format("\\u%04x", c:byte())
  end) .. '"'
end

function ser(v)
  local t = type(v)
  if t == "nil" then return "null"
  elseif t == "boolean" then return tostring(v)
  elseif t == "number" then
    if math.type(v) == "integer" then return tostring(v) end
    return string.format("%.10g", v)
  elseif t == "string" then return esc(v)
  elseif t == "table" then
    if next(v) == nil then return "[]" end
    if is_array(v) then
      local parts = {}
      for i = 1, #v do parts[#parts + 1] = ser(v[i]) end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do
      local val = v[k]
      if val == nil then val = v[tonumber(k)] end
      parts[#parts + 1] = esc(k) .. ":" .. ser(val)
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return "null"
end
