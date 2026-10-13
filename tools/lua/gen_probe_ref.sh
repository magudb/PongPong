#!/bin/bash
# Regenerates tests/fixtures/lua/probe_expected.json with REAL Lua 5.4 (see tools/lua/gen_probe_ref.lua).
set -e
cd "$(dirname "$0")/../.."
LUA=$(command -v lua5.4 || command -v lua || true)
if [ -z "$LUA" ]; then echo "gen_probe_ref: no lua5.4 on the PATH (brew install lua)" >&2; exit 2; fi
"$LUA" -v >&2
"$LUA" tools/lua/gen_probe_ref.lua tests/fixtures/lua tools/lua/probe_cases.lua tools/lua/ref_ser.lua > tests/fixtures/lua/probe_expected.json.tmp
mv tests/fixtures/lua/probe_expected.json.tmp tests/fixtures/lua/probe_expected.json
echo "wrote tests/fixtures/lua/probe_expected.json"
