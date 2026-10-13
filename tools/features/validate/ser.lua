-- ser.lua: evaluate project Lua data files with REAL Lua 5.4 in a sandbox and dump their tables as JSON.
--   lua5.4 ser.lua out.json file1.lua file2.lua ...
-- Only global tables / strings / numbers / booleans are dumped (functions are skipped, they are not data).
local function esc(s)
  return '"' .. s:gsub('[%c"\\]', function(c)
    local m = {['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\t'] = '\\t', ['\r'] = '\\r'}
    return m[c] or string.format("\\u%04x", c:byte())
  end) .. '"'
end

local function is_array(t)
  local n = 0
  for k in pairs(t) do
    if math.type(k) ~= "integer" then return false end
    n = n + 1
  end
  for i = 1, n do if t[i] == nil then return false end end
  return true
end

local function ser(v)
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

local out = arg[1]
local files = {}
for i = 2, #arg do files[#files + 1] = arg[i] end
local results = {}
for _, path in ipairs(files) do
  local env = {}
  local f, err = loadfile(path, "t", env)
  local rec = {file = path}
  if not f then
    rec.error = err
  else
    local ok, e2 = pcall(f)
    if not ok then rec.error = tostring(e2) end
  end
  local names = {}
  for k, v in pairs(env) do
    if type(v) ~= "function" then names[#names + 1] = k end
  end
  table.sort(names)
  local parts = {}
  for _, k in ipairs(names) do parts[#parts + 1] = esc(k) .. ":" .. ser(env[k]) end
  local fn = {}
  for k, v in pairs(env) do if type(v) == "function" then fn[#fn + 1] = esc(k) end end
  table.sort(fn)
  rec.json = '{"file":' .. esc(path) .. ',"error":' .. (rec.error and esc(rec.error) or "null") .. ',"globals":{' .. table.concat(parts, ",") .. '},"functions":[' .. table.concat(fn, ",") .. ']}'
  results[#results + 1] = rec.json
end
local fh = assert(io.open(out, "w"))
fh:write("[" .. table.concat(results, ",\n") .. "]")
fh:close()
