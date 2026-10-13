# tools/lua - Lua data tooling (package P10)

The game reads its data (config, items, quests, dialogue, shops, recipes) from `lua/**` through `LuaRuntime`
(`scripts/autoload/lua_runtime.gd`), a pure-GDScript interpreter of a small, documented Lua **subset**.
Everything outside the subset is reported at load time by the lint (`LuaRuntime.lint_report`), never as an engine warning.

## The subset in one paragraph

Top-level assignments of literal tables (`config = { ... }`, `items = { ... }`, `shops = { ... }`, `recipes = { ... }`),
a `kind = "config|items|quest|dialogue|recipes|shops"` header (it decides what a file is, in any directory, also under
`lua/data/**`), and top-level `function name(args) ... end` bodies made of `local x = expr`, `if cond then ... end`
(nesting and one-line `if` are fine), `return <table literal or expression>` and the calls `api.add_gold add_item remove_item
set_flag get_flag has_flag has_item get_gold notification unlock_zone emit log offer_quest complete_quest`.
Expressions: literals, `context.x`, `api.f(...)`, `and or not == ~= < <= > >= ..` with Lua precedence and truthiness
(only `nil` and `false` are false). A bare identifier that is not a local or a parameter reads the **world flag** of that
name, so `local tier = context.home_tier or home_tier or 1` works.
Table values are literals (string, number, `true`/`false`, nested table); `{}` arrives as an empty Dictionary.

## `lint.gd` - lint every Lua file

```
godot --headless --path . -s res://tools/lua/lint.gd                                  # res://lua/**   (exit 0 = clean)
godot --headless --path . -s res://tools/lua/lint.gd -- --root=res://tests/fixtures/lua --quiet
godot --headless --path . -s res://tools/lua/lint.gd -- --files=res://lua/quests/lost_cat.lua,/abs/path/x.lua
```

Prints `PASS <file>` or `FAIL <file>:<line>:<rule> <message>` per finding and a `lint: N file(s), M finding(s)` line.
Rules: `else elseif loop long_bracket local_function module_function escape length stdlib method_call vararg arithmetic
bitwise mixed_table table_value nil_value kind_missing kind_unknown unbalanced unterminated_string stray_character`
(and, from the loader: `duplicate_key rarity tables_header`). `LuaRuntime.lint_source(text)` lints a string (docs, tests).

## `gen_probe_ref.sh` - reference values from REAL Lua

`tests/fixtures/lua/p01..p23.lua` are the audit probes (small files that exercise one Lua feature each), `semantics.lua`
and `lint_clean_sample.lua` add the semantics of the subset. `probe_cases.lua` lists the cases (function, arguments, world
flags, mode); `gen_probe_ref.sh` runs them through **real Lua 5.4** (`brew install lua`) and stores the results in
`tests/fixtures/lua/probe_expected.json`. `tests/sections/data.gd` (`data.lua_probes`) replays the same cases through
LuaRuntime and compares result and side effects. Modes: `exact` (inside the subset: must equal real Lua and lint clean),
`best_effort` (outside the subset: the lint must flag it, the runtime still reproduces Lua), `flagged` (only the lint is
asserted). To add a probe: put the file next to the others, add cases, run `gen_probe_ref.sh`, commit the JSON.

Run the whole section: `tests/run_playtest.sh --only=data,rarity`.
