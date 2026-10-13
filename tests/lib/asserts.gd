extends RefCounted
## Check recording for the playtest harness: expect / check / expect_eq / expect_near / fail / skip / info.
## This is the bottom of the `t` object that every section receives (asserts -> drive -> flow -> t).
##
## Check names: the plan requires "<section>.<check>" names (8.2, 8.5) so reviewers can grep for them.
##   t.check("loop_all_crops", cond, "7 of 7 crops")   prints   ok    farm.loop_all_crops (7 of 7 crops)
##   t.expect(cond, "free text label")                  prints   ok    free text label
## Failures are always listed in the final summary as "<section>.<label>".

## Set by the harness for the section that is running.
var section: String = ""
var checks: int = 0
var failed: int = 0
var skipped: int = 0
## "<section>.<label>" of every failed check, in order.
var failures: Array[String] = []
## Per-section statistics: name -> {checks, failed, skipped, ms}.
var stats: Dictionary = {}
## Print every ok line (default: stop after max_ok_lines per section and count the rest).
var verbose: bool = false
var max_ok_lines: int = 400

var _ok_printed: int = 0
var _ok_suppressed: int = 0
var _section_t0: int = 0


# ---------------------------------------------------------------- section bookkeeping (used by the harness)

func begin_section(section_name: String) -> void:
	section = section_name
	_ok_printed = 0
	_ok_suppressed = 0
	_section_t0 = Time.get_ticks_msec()
	stats[section_name] = {"checks": 0, "failed": 0, "skipped": 0, "ms": 0}


func end_section() -> void:
	if _ok_suppressed > 0:
		print("  ...   (%d more ok lines of %s not printed; --verbose prints all)" % [_ok_suppressed, section])
	if stats.has(section):
		stats[section]["ms"] = Time.get_ticks_msec() - _section_t0


func _count(ok: bool) -> void:
	checks += 1
	var s: Dictionary = stats.get(section, {})
	if not s.is_empty():
		s["checks"] = int(s["checks"]) + 1
		if not ok:
			s["failed"] = int(s["failed"]) + 1


func _ok_line(text: String) -> void:
	if verbose or _ok_printed < max_ok_lines:
		_ok_printed += 1
		print("  ok    ", text)
	else:
		_ok_suppressed += 1


func _record_failure(label: String) -> void:
	failed += 1
	failures.append("%s.%s" % [section, label])
	print("  FAIL  ", label)


# ---------------------------------------------------------------- checks

## Free-text check. `cond` may be any value: false / null / 0 / "" / empty containers are false.
func expect(cond: Variant, label: Variant = "") -> bool:
	var ok := bool(cond)
	_count(ok)
	if ok:
		_ok_line(str(label))
	else:
		_record_failure(str(label))
	return ok


## Named check: the printed and summarised name is "<section>.<name>" so it can be grepped for.
func check(check_name: String, cond: Variant, detail: Variant = "") -> bool:
	var ok := bool(cond)
	_count(ok)
	var label := "%s.%s" % [section, check_name]
	if str(detail) != "":
		label += " (%s)" % str(detail)
	if ok:
		_ok_line(label)
	else:
		failed += 1
		failures.append("%s.%s" % [section, check_name])
		print("  FAIL  ", label)
	return ok


## Deep equality (Variant ==): 1 == 1.0, &"a" == "a", [1, 2] == [1, 2]; mismatching types are simply not equal.
func expect_eq(actual: Variant, expected: Variant, label: Variant = "") -> bool:
	var ok: bool = (actual == expected)
	var text := "%s (got %s, want %s)" % [str(label), _show(actual), _show(expected)]
	_count(ok)
	if ok:
		_ok_line(text)
	else:
		_record_failure(text)
	return ok


func expect_near(actual: float, expected: float, eps: float, label: Variant = "") -> bool:
	var ok := absf(actual - expected) <= eps
	var text := "%s (got %s, want %s +/- %s)" % [str(label), actual, expected, eps]
	_count(ok)
	if ok:
		_ok_line(text)
	else:
		_record_failure(text)
	return ok


## `container` is a Dictionary (key), Array/PackedArray (value) or String (substring).
func expect_has(container: Variant, item: Variant, label: Variant = "") -> bool:
	var ok := false
	match typeof(container):
		TYPE_DICTIONARY: ok = (container as Dictionary).has(item)
		TYPE_STRING, TYPE_STRING_NAME: ok = str(item) in str(container)
		TYPE_NIL: ok = false
		_: ok = item in container
	var text := "%s (%s in %s)" % [str(label), _show(item), _show(container, 80)]
	_count(ok)
	if ok:
		_ok_line(text)
	else:
		_record_failure(text)
	return ok


func fail(label: Variant) -> void:
	_count(false)
	_record_failure(str(label))


## A check that cannot run here (missing optional package, headless-only gap). Printed and counted as skipped, never a failure.
func skip(label: Variant) -> void:
	skipped += 1
	var s: Dictionary = stats.get(section, {})
	if not s.is_empty():
		s["skipped"] = int(s["skipped"]) + 1
	print("  SKIP  ", str(label))


func info(message: Variant) -> void:
	print("  info  ", str(message))


func _show(v: Variant, limit: int = 60) -> String:
	var s := str(v)
	if s.length() > limit:
		s = s.substr(0, limit) + "..."
	return s
