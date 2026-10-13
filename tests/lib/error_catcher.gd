extends Logger
## Engine / script error AND warning capture for the playtest harness (OS.add_logger).
##
## Every message the engine routes through the Logger (push_error, push_warning, GDScript runtime errors,
## parse errors, C++ ERR_* / WARN_* macros, shader errors) is recorded here. ANY recorded message fails
## the run, unless a section declared it as expected with t.allow(substring) (scoped to that section).
##
## Logger callbacks may arrive from any thread (resource loader threads, audio, ...), so every access to the
## buffers goes through the mutex. Nothing is printed from inside the callback (it can run inside print()).

const KIND_NAMES := {0: "error", 1: "warning", 2: "script error", 3: "shader error"}

## Section the next message is attributed to ("boot" before the first section, "-" between sections).
var section: String = "boot"
## Messages that fail the run: Array of {section, kind, text}.
var entries: Array[Dictionary] = []
## Messages that matched an allow() rule: Array of {section, kind, text, rule}.
var allowed_entries: Array[Dictionary] = []
## rule substring -> hit count (only rules declared in the current section).
var allow_hits: Dictionary = {}
## Known, documented issues of the tree (tests/lib/known_issues.txt): matched messages do not fail the run but are
## always listed. rule -> {reason, hits}. Unlike allow() they apply to the whole run.
var known_rules: Dictionary = {}
var known_entries: Array[Dictionary] = []

var _rules: Array[String] = []
var _mutex := Mutex.new()
var _capture: Array = []        # non-empty scope stack while capture_begin() is active
var _capturing: bool = false


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	var text := "%s:%d in %s(): %s" % [file, line, function, code]
	if rationale != "":
		text += " " + rationale
	var where := _script_frame(script_backtraces)
	if where != "":
		text += " (at " + where + ")"
	var kind: String = KIND_NAMES.get(error_type, "error")
	_mutex.lock()
	if _capturing:
		_capture.append({"kind": kind, "text": text})
		_mutex.unlock()
		return
	for rule in _rules:
		if rule in text:
			allow_hits[rule] = int(allow_hits.get(rule, 0)) + 1
			allowed_entries.append({"section": section, "kind": kind, "text": text, "rule": rule})
			_mutex.unlock()
			return
	for rule in known_rules:
		if rule in text:
			known_rules[rule]["hits"] = int(known_rules[rule]["hits"]) + 1
			known_entries.append({"section": section, "kind": kind, "text": text, "rule": rule})
			_mutex.unlock()
			return
	entries.append({"section": section, "kind": kind, "text": text})
	_mutex.unlock()


## "function res://file.gd:line" of the innermost script frame, so an engine-side error says which script caused it.
func _script_frame(backtraces: Array[ScriptBacktrace]) -> String:
	for bt in backtraces:
		if bt != null and not bt.is_empty() and bt.get_frame_count() > 0:
			return "%s %s:%d" % [bt.get_frame_function(0), bt.get_frame_file(0), bt.get_frame_line(0)]
	return ""


# ---------------------------------------------------------------- known issues (whole run)

func add_known(rule: String, reason: String, source: String = "") -> void:
	_mutex.lock()
	known_rules[rule] = {"reason": reason, "source": source, "hits": 0}
	_mutex.unlock()


# ---------------------------------------------------------------- allow rules (scoped to one section)

func allow(substring: String) -> void:
	_mutex.lock()
	if substring not in _rules:
		_rules.append(substring)
	if not allow_hits.has(substring):
		allow_hits[substring] = 0
	_mutex.unlock()


func clear_allow() -> void:
	_mutex.lock()
	_rules.clear()
	allow_hits.clear()
	_mutex.unlock()


func allowed_count(substring: String) -> int:
	_mutex.lock()
	var n := int(allow_hits.get(substring, 0))
	_mutex.unlock()
	return n


# ---------------------------------------------------------------- read side

func mark() -> int:
	_mutex.lock()
	var n := entries.size()
	_mutex.unlock()
	return n


func since(mark_value: int) -> Array[String]:
	var out: Array[String] = []
	_mutex.lock()
	for i in range(mark_value, entries.size()):
		out.append("[%s] %s: %s" % [entries[i]["section"], entries[i]["kind"], entries[i]["text"]])
	_mutex.unlock()
	return out


func count() -> int:
	return mark()


func count_kind(kind: String) -> int:
	var n := 0
	_mutex.lock()
	for e in entries:
		if e["kind"] == kind:
			n += 1
	_mutex.unlock()
	return n


## First message at or after `mark_value` that came from a script runtime error (it killed a coroutine).
func script_error_since(mark_value: int) -> String:
	var found := ""
	_mutex.lock()
	for i in range(mark_value, entries.size()):
		if entries[i]["kind"] == "script error":
			found = entries[i]["text"]
			break
	_mutex.unlock()
	return found


# ---------------------------------------------------------------- scoped capture (used while compiling sections)

## Everything logged between capture_begin() and capture_end() goes to a private buffer instead of the run's
## failure list, so a section that is not selected can be probed without failing the run.
func capture_begin() -> void:
	_mutex.lock()
	_capture = []
	_capturing = true
	_mutex.unlock()


func capture_end() -> Array:
	_mutex.lock()
	var out := _capture
	_capture = []
	_capturing = false
	_mutex.unlock()
	return out


## Re-record captured messages as real failures (attributed to `for_section`).
func commit(captured: Array, for_section: String) -> void:
	_mutex.lock()
	for m in captured:
		entries.append({"section": for_section, "kind": m["kind"], "text": m["text"]})
	_mutex.unlock()
