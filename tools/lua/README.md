# tools/lua - Lua data tooling (package P10)

The game reads its data (config, items, quests, dialogue, shops, recipes, registries) from `lua/**` through `LuaRuntime`
(`scripts/autoload/lua_runtime.gd`), a pure-GDScript interpreter of a small, documented Lua **subset**.
Everything outside the subset is reported at load time by the lint (`LuaRuntime.lint_report`), never as an engine warning.

## The subset in one paragraph

Top-level assignments of literal tables (`config = { ... }`, `items = { ... }`, `shops = { ... }`, `recipes = { ... }`),
a `kind = "config|items|quest|dialogue|recipes|shops|registry"` header (it decides what a file is, in any directory, also under
`lua/data/**`), and top-level `function name(args) ... end` bodies made of `local x = expr`, `if cond then ... end`
(nesting and one-line `if` are fine), `return <table literal or expression>` and the calls `api.add_gold add_item remove_item
set_flag get_flag has_flag has_item get_gold notification unlock_zone emit log offer_quest complete_quest` and the four social
functions `get_hearts add_hearts is_birthday festival` (below).
Expressions: literals, `context.x`, `api.f(...)`, `and or not == ~= < <= > >= ..` with Lua precedence and truthiness
(only `nil` and `false` are false). A bare identifier that is not a local or a parameter reads the **world flag** of that
name, so `local tier = context.home_tier or home_tier or 1` works.
Table values are literals (string, number, `true`/`false`, nested table); `{}` arrives as an empty Dictionary.

## The `registry` kind - one Lua file per citizen / building / festival

```lua
kind = "registry"
registry = "routines"          -- the name of the registry; the file must hold a top-level table of that name
routines = {
  gardener_hoppe = { home = "hoppe_hut", plans = { work = { blocks = { { from = 6.5, at = "home.table", act = "eat" } } } } },
}
```

`LuaRuntime.get_registry("routines") -> Dictionary` (id -> def, load order) and `get_registry_entry("routines", "gardener_hoppe")
-> Dictionary` answer `{}` for an unknown name or id (never null); both are the live data: treat them as read-only (as
`get_recipes`). Several files may feed one registry; each id is claimed once per registry: a second file defining it is a
`duplicate_id` note in `LuaRuntime.data_report` (the later file wins, never a lint failure), the same id in ANOTHER registry is fine.
A `kind = "registry"` file without `registry = "<name>"`, without its table, or named like a parser result key
(`functions table_assigns source_path kind id`) is the finding `registry_header` and registers nothing. The registries of the
towns / social tracks are `routines`, `buildings`, `events`, `festivals` (addendum 8.6). Entries are tables; the loader does not
look inside them (their validators do). **`until` is a Lua reserved word** and cannot be a table key (real Lua rejects it, the
lint says `reserved_key`): routine blocks use `leave` / `stay` / `from`.

## The social api functions (late-bound to `SocialManager`, S-core)

| Call | Answer | Forwards to |
|---|---|---|
| `api.get_hearts(npc)` | whole hearts, int | `SocialManager.hearts(npc)` |
| `api.add_hearts(npc, n)` | nil (a missing `n` adds nothing; raises only) | `SocialManager.add_hearts(npc, n, &"lua")` |
| `api.is_birthday(npc)` | bool | `SocialManager.is_birthday(npc)` |
| `api.festival()` | the id of today's ACTIVE festival, `""` when none | `SocialManager.festival_active()` |

Without the autoload (or when it lacks the method) every one of them answers nil and changes nothing: no manager, no answer.
Two traps for content: `""` is TRUTHY in Lua, so test `api.festival() ~= ""`, never `if api.festival() then`; and an unset flag
reads nil, so dialogue modules keep reading hearts as `local h = context.hearts or friend_x or 0` (or `api.get_hearts(npc) or 0`).

## `lint.gd` - lint every Lua file

```
godot --headless --path . -s res://tools/lua/lint.gd                                  # res://lua/**   (exit 0 = clean)
godot --headless --path . -s res://tools/lua/lint.gd -- --root=res://tests/fixtures/lua --quiet
godot --headless --path . -s res://tools/lua/lint.gd -- --files=res://lua/quests/lost_cat.lua,/abs/path/x.lua
```

Prints `PASS <file>` or `FAIL <file>:<line>:<rule> <message>` per finding and a `lint: N file(s), M finding(s)` line.
Rules: `else elseif loop long_bracket local_function module_function escape length stdlib method_call vararg arithmetic
bitwise mixed_table reserved_key table_value nil_value kind_missing kind_unknown unbalanced unterminated_string stray_character
unknown_function` over the tokens, the grammar findings of the parser `syntax local_list field_assignment function_value
unsupported top_level` (what it could not use: `!=`, `if a = b then`, `retrun x`, a statement after `return`, `t.x = v`,
`local f = function() ... end`, a call that is not `api.<name>(...)` ...), and, from the loader: `duplicate_key rarity
tables_header registry_header`. `LuaRuntime.lint_source(text)` lints a string (docs, tests).
The lint is a deny-list; the independent gate is real Lua: `data.lua_real_syntax` runs `luac5.4 -p` over every file under
`res://lua` (the playtest workflow installs lua5.4; without it the check is skipped locally and fails on CI).
`LuaRuntime` lints at load only in debug builds (`lint_on_load`); a release build keeps the loader's data-level checks.

## `gen_probe_ref.sh` - reference values from REAL Lua

`tests/fixtures/lua/p01..p23.lua` are the audit probes (small files that exercise one Lua feature each), `semantics.lua`
and `lint_clean_sample.lua` add the semantics of the subset. `probe_cases.lua` lists the cases (function, arguments, world
flags, mode); `gen_probe_ref.sh` runs them through **real Lua 5.4** (`brew install lua`) and stores the results in
`tests/fixtures/lua/probe_expected.json`. `tests/sections/data.gd` (`data.lua_probes`) replays the same cases through
LuaRuntime and compares result and side effects. Modes: `exact` (inside the subset: must equal real Lua and lint clean),
`best_effort` (outside the subset: the lint must flag it, the runtime still reproduces Lua), `flagged` (only the lint is
asserted). To add a probe: put the file next to the others, add cases, run `gen_probe_ref.sh`, commit the JSON.

Run the whole section: `tests/run_playtest.sh --only=data,rarity`; the registry kind, the four social functions and the
`reserved_key` rule are covered by `tests/sections/data_registry.gd` (`--only=data_registry`, fixtures `registry_*.lua`,
`social_api.lua`).
