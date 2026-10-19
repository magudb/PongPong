-- tools/lua/probe_cases.lua: the cases replayed against the 23 audit probes in tests/fixtures/lua (data.lua_probes).
-- Each case: probe (file stem), fn (the Lua function to call), args (the call arguments, a list), flags (world flags the
-- bare identifiers and api.get_flag / api.has_flag read), label, mode, lint (rule ids the file must report).
--
-- mode "exact"       inside the supported subset: LuaRuntime must reproduce real Lua 5.4 (result AND side effects), lint clean
--      "best_effort" outside the documented subset but the runtime still reproduces real Lua; the lint MUST flag it
--      "flagged"     outside the subset, not reproduced: only the lint is asserted (and that nothing raises an engine error)
-- The reference values are NOT written here: tools/lua/gen_probe_ref.sh runs real Lua and stores them in
-- tests/fixtures/lua/probe_expected.json.

local function c(probe, fn, args, flags, label, mode, lint)
  return { probe = probe, fn = fn, args = args, flags = flags or {}, label = label, mode = mode, lint = lint or {} }
end

return {
  -- p01: an empty / comment-only function must not swallow the next one (the old regex bug of intro_lottery.lua)
  c("p01_empty_fn", "a", { {} }, {}, "empty function returns nothing", "exact"),
  c("p01_empty_fn", "b", { {} }, {}, "the function after the empty one is its own", "exact"),
  -- p02 / p03: else and elseif are outside the subset (lint) but evaluated correctly
  c("p02_else", "get_dialogue", { { x = true } }, {}, "x true -> then", "best_effort", { "else" }),
  c("p02_else", "get_dialogue", { { x = false } }, {}, "x false -> else", "best_effort", { "else" }),
  c("p03_elseif", "get_dialogue", { { x = true } }, {}, "x -> x", "best_effort", { "elseif" }),
  c("p03_elseif", "get_dialogue", { { y = true } }, {}, "y -> y", "best_effort", { "elseif" }),
  c("p03_elseif", "get_dialogue", { {} }, {}, "none -> none", "best_effort", { "elseif" }),
  -- p04 / p05: nested if and one-line if
  c("p04_nested_if", "get_dialogue", { { a = true, b = true } }, {}, "a and b", "exact"),
  c("p04_nested_if", "get_dialogue", { { a = true } }, {}, "a only", "exact"),
  c("p04_nested_if", "get_dialogue", { {} }, {}, "neither", "exact"),
  c("p05_oneline_if", "get_dialogue", { { x = true } }, {}, "x", "exact"),
  c("p05_oneline_if", "get_dialogue", { {} }, {}, "no x", "exact"),
  -- p06 / p07 / p10 / p13 / p16: bare identifiers, arithmetic, helpers and the standard library are not evaluated in tables
  c("p06_ternary", "get_dialogue", { { x = true } }, {}, "x and yes or no", "flagged", { "table_value" }),
  c("p07_arith", "get_dialogue", { { base = 4 } }, {}, "arithmetic", "flagged", { "arithmetic", "table_value" }),
  c("p10_get_flag", "get_dialogue", { {} }, { seen = true }, "api.get_flag into a local", "flagged", { "table_value" }),
  c("p13_helper", "get_dialogue", { {} }, {}, "local function helper", "flagged", { "local_function", "table_value" }),
  c("p16_stdlib", "get_dialogue", { {} }, {}, "#, string.format, string.upper", "flagged", { "length", "stdlib", "table_value" }),
  -- p08: ')' inside a string argument; the call after it must still run
  c("p08_paren_in_string", "on_accept", { {} }, {}, "paren in notification text", "exact"),
  -- p09: api.emit carries its payload
  c("p09_emit_payload", "on_accept", { {} }, {}, "emit with payload table", "exact"),
  -- p11: loops are outside the subset
  c("p11_loop", "on_accept", { {} }, {}, "for loop", "flagged", { "loop" }),
  -- p12: block comment is skipped properly (lint still reports [[ ]])
  c("p12_block_comment", "on_accept", { {} }, {}, "function inside a block comment is not defined", "best_effort", { "long_bracket" }),
  -- p14: two identical ifs both run
  c("p14_two_ifs", "handle_event", { "quest_completed", {} }, {}, "two ifs, both taken", "exact"),
  c("p14_two_ifs", "handle_event", { "quest_failed", {} }, {}, "two ifs, none taken", "exact"),
  -- p15: escaped quotes (lint) but read correctly, and the field after the string survives
  c("p15_escape", "get_dialogue", { {} }, {}, "escaped quotes in a text", "best_effort", { "escape" }),
  -- p17: if/else around api calls
  c("p17_ifelse_api", "handle_event", { "x", {} }, { bonus = true }, "bonus branch", "best_effort", { "else" }),
  c("p17_ifelse_api", "handle_event", { "x", {} }, {}, "else branch", "best_effort", { "else" }),
  -- p18: `and` binds tighter than `or`
  c("p18_compare_and_or", "get_dialogue", { { a = true, b = true } }, {}, "a and b", "exact"),
  c("p18_compare_and_or", "get_dialogue", { { c = true } }, {}, "only c", "exact"),
  c("p18_compare_and_or", "get_dialogue", { { a = true } }, {}, "only a (a and b is false, c is false)", "exact"),
  c("p18_compare_and_or", "get_dialogue", { {} }, {}, "none", "exact"),
  -- p19: return of a boolean expression
  c("p19_return_expr", "is_available", { {} }, {}, "has_item and not has_flag", "exact"),
  c("p19_return_expr", "is_available", { {} }, { done = true }, "done flag set", "exact"),
  -- p20: a local in an untaken branch is not evaluated
  c("p20_local_in_untaken", "get_dialogue", { {} }, {}, "branch not taken", "exact"),
  c("p20_local_in_untaken", "get_dialogue", { { never = true } }, {}, "branch taken", "exact"),
  -- p21: a multi-line api call
  c("p21_multiline_api", "on_accept", { {} }, {}, "notification over three lines", "exact"),
  -- p22: module style
  c("p22_module_style", "get_dialogue", { {} }, {}, "function M.get_dialogue", "flagged", { "module_function" }),
  -- semantics.lua (not an audit probe): truthiness, mixed compare, precedence, parentheses, flags as bare identifiers
  c("semantics", "zero_is_true", { {} }, {}, "0 is true in Lua", "exact"),
  c("semantics", "empty_string_is_true", { {} }, {}, "the empty string is true in Lua", "exact"),
  c("semantics", "nil_and_false_are_false", { { off = false } }, {}, "nil and false are the only false values", "exact"),
  c("semantics", "mixed_compare", { {} }, {}, "false == 3 is false, never an error", "exact"),
  c("semantics", "precedence", { { a = true } }, {}, "a or (b and c): a", "exact"),
  c("semantics", "precedence", { { b = true } }, {}, "a or (b and c): only b", "exact"),
  c("semantics", "precedence", { { b = true, c = true } }, {}, "a or (b and c): b and c", "exact"),
  c("semantics", "precedence", { {} }, {}, "a or (b and c): none", "exact"),
  c("semantics", "parentheses", { { a = true } }, {}, "(a or b) and c: only a", "exact"),
  c("semantics", "parentheses", { { a = true, c = true } }, {}, "(a or b) and c: a and c", "exact"),
  c("semantics", "parentheses", { { b = true, c = true } }, {}, "(a or b) and c: b and c", "exact"),
  c("semantics", "not_binds_tight", { { b = true } }, {}, "(not a) and b: b only", "exact"),
  c("semantics", "not_binds_tight", { { a = true, b = true } }, {}, "(not a) and b: a and b", "exact"),
  c("semantics", "compare_numbers", { { n = 7 } }, {}, "7 is mid", "exact"),
  c("semantics", "compare_numbers", { { n = 12 } }, {}, "12 is high", "exact"),
  c("semantics", "compare_numbers", { { n = 10 } }, {}, "10 is low (not > 10, not < 10)", "exact"),
  c("semantics", "compare_numbers", { { n = 2 } }, {}, "2 is low", "exact"),
  c("semantics", "compare_strings", { { name = "lily" } }, {}, "lily", "exact"),
  c("semantics", "compare_strings", { { name = "oak" } }, {}, "oak", "exact"),
  c("semantics", "compare_strings", { { name = "fox" } }, {}, "fox", "exact"),
  c("semantics", "concat_in_log", { {} }, {}, "concat in a log call", "exact"),
  c("semantics", "flag_value", { {} }, { seen = true }, "api.get_flag returns the value", "exact"),
  c("semantics", "flag_value", { {} }, {}, "api.get_flag of an unset flag is nil", "exact"),
  c("semantics", "flag_as_bare_identifier", { {} }, { seen = true }, "seen and not gone", "exact"),
  c("semantics", "flag_as_bare_identifier", { {} }, { seen = true, gone = true }, "seen and gone", "exact"),
  c("semantics", "flag_as_bare_identifier", { {} }, {}, "no flags", "exact"),
  c("semantics", "side_effects_in_order", { { stop = true } }, {}, "early return keeps the effects before it", "exact"),
  c("semantics", "side_effects_in_order", { {} }, {}, "no early return", "exact"),
  -- lint_clean_sample.lua: the supported subset in one file
  c("lint_clean_sample", "on_accept", { { seen = true, count = 3 } }, {}, "nested ifs, locals, comparisons", "exact"),
  c("lint_clean_sample", "on_accept", { { never = true } }, {}, "one-line if", "exact"),
  c("lint_clean_sample", "on_accept", { {} }, {}, "fall through to the last return", "exact"),
  c("lint_clean_sample", "is_available", { {} }, {}, "boolean expression with parentheses", "exact"),
  -- p23: statements before and after an if
  c("p23_stmt_around_if", "on_accept", { { x = true } }, {}, "x true", "exact"),
  c("p23_stmt_around_if", "on_accept", { { x = false } }, {}, "x false", "exact"),
  -- p24 / p25: block scopes and integral float keys (LUA-07)
  c("p24_block_scope", "get_dialogue", { { up = true } }, {}, "an inner local shadows only inside its block", "exact"),
  c("p24_block_scope", "get_dialogue", { {} }, {}, "branch not taken", "exact"),
  c("p24_block_scope", "assign_outer", { { up = true } }, {}, "an assignment in a block sets the outer local", "exact"),
  c("p24_block_scope", "shadow_param", { { up = true } }, {}, "a local may shadow a parameter inside a block", "exact"),
  c("p25_float_index", "get_dialogue", { { stage = 2.0 } }, {}, "array index by an integral float", "exact"),
  c("p25_float_index", "get_dialogue", { { stage = 4 } }, {}, "array index by an integer", "exact"),
  c("p25_float_index", "get_dialogue", { { stage = 2.5 } }, {}, "a fractional index misses", "exact"),
  c("p25_float_index", "by_key", { { stage = 3.0 } }, {}, "[n] = key by an integral float", "exact"),
}
