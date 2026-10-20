extends SceneTree
## Playtest harness (plan 8.1). It is ONLY the harness: boots the real game flow, discovers and runs the
## section files other packages own, captures every engine/script error and warning, and sets the exit code.
##
##   tests/run_playtest.sh [--character=animal|fairy|hobbit|ghost] [--only=core,farm] [--list] [--windowed ...]
##   godot --headless --path . -s res://tests/playtest.gd -- --character=fairy --only=core        (what the script runs)
##
## Options after `--`:
##   --character=animal|fairy|hobbit|ghost   hero for the boot stage and t.character (default animal)
##   --only=a,b                        run only these sections (SECTION name or file name; unknown names are an error)
##   --list                            print the discovered sections and exit (non-zero if one does not compile)
##   --windowed                        real-window run: only sections with run_windowed(t), no boot stage
##                                     (the wrapper adds --resolution 1280x720 and opens a window)
##   --out=DIR                         screenshots (t.capture) are written here
##   --no-boot / --boot                skip / force the boot stage (default: boot in headless runs, none windowed)
##   --play-seconds=N                  idle seconds after the boot stage so the world can tick (default 2)
##   --scenario=flow                   accepted for compatibility with the old harness (the only scenario)
##   --sections-dir=PATH               sections directory (default res://tests/sections; used by the harness self-test)
##   --section-timeout=N               default per-section watchdog in seconds (default 120; a section may set TIMEOUT_S)
##   --max-seconds=N                   watchdog for the whole run (default 1200)
##   --report=FILE                     also write a JSON result file
##   --seed=N                          seed of t.rng (default 424242)
##   --strict                          ignore tests/lib/known_issues.txt: every engine message fails the run
##   --known-issues=PATH               one more known-issues file besides res://tests/lib/known_issues.txt (repeatable)
##   --verbose                         print every ok line (default: at most 400 per section)
## The wrapper (tests/run_playtest.sh) has options of its own that this script never sees: --fast (headless: `--fixed-fps 60`, frames run ahead of the
## wall clock), --no-import, --timeout=SECS, --keep-home. The watchdogs of this script (--section-timeout, TIMEOUT_S, --max-seconds) count WALL-CLOCK seconds.
##
## Section file contract (res://tests/sections/<name>.gd, alphabetical order, files starting with "_" are ignored):
##   extends RefCounted
##   const SECTION := "farm"
##   func run(t) -> void                optional func run_windowed(t) -> void       optional const TIMEOUT_S := 60.0
## `t` is tests/lib/t.gd (check / expect / allow / frames / physics / seconds / tap / press / boot / ...).
##
## Failure rules: a failed check, ANY engine or script error, ANY engine warning (unless the section declared it
## with t.allow(substring), or it is a documented known issue of the tree, see known_issues.txt: those are always
## listed as KNOWN and never silent), a section that does not compile, or a section that times out
## all make the run exit 1. Usage errors exit 2. A section that does not compile fails the run at once, before
## anything else runs (with --only, an uncompilable file that was not selected is reported but not fatal).
##
## This script compiles BEFORE the autoloads exist: it never names an autoload (tests/lib reaches them with
## root.get_node) and loads its libraries with load().

const LIB := "res://tests/lib/"
const DEFAULT_SECTIONS_DIR := "res://tests/sections"
const WINDOW_SIZE := Vector2i(1280, 720)
const SLOW_SECTION_S := 30.0

var _t                                   # tests/lib/t.gd (untyped on purpose: it is duck-typed, loaded at runtime)
var _catcher                             # tests/lib/error_catcher.gd (a Logger)

var _character := "animal"
var _only: Array[String] = []
var _list := false
var _windowed := false
var _out := ""
var _boot_mode := "auto"                 # auto | yes | no
var _play_seconds := 2.0
var _sections_dir := DEFAULT_SECTIONS_DIR
var _section_timeout := 120.0
var _max_seconds := 1200.0
var _report := ""
var _seed := 424242
var _verbose := false
var _strict := false
var _fast := false
var _known_paths: Array[String] = ["res://tests/lib/known_issues.txt"]

var _t0 := 0
var _problems: Array[String] = []        # run-level failures that are not checks (compile errors, timeouts, ...)
var _sections: Array[Dictionary] = []    # discovered: {base, name, path, script, compiled, has_run, has_win, timeout, selected}
var _ran: Array[String] = []
var _aborted := false                    # a timeout stopped the run
var _finished := false
var _usage_error := false
var _help := false
var _guard_done := false


func _initialize() -> void:
	_t0 = Time.get_ticks_msec()
	var usage := _parse_args(OS.get_cmdline_user_args())
	if usage != "":
		print("PLAYTEST usage error: ", usage)
		_print_usage()
		quit(2)
		return
	if _help:
		print("PLAYTEST help")
		_print_usage()
		quit(0)
		return
	var catcher_script: Variant = load(LIB + "error_catcher.gd")
	var t_script: Variant = load(LIB + "t.gd")
	if not (catcher_script is GDScript) or not (t_script is GDScript) or not (catcher_script as GDScript).can_instantiate() or not (t_script as GDScript).can_instantiate():
		print("PLAYTEST FAIL: the harness libraries in tests/lib do not compile")
		quit(1)
		return
	_catcher = (catcher_script as GDScript).new()
	OS.add_logger(_catcher)
	_t = (t_script as GDScript).new()
	_t.bind(self)
	_t.catcher = _catcher
	_t.character = _character
	_t.windowed = _windowed
	_t.out_dir = _out
	_t.verbose = _verbose
	_t.fast = _fast
	_t.user_dir = OS.get_user_data_dir()
	_t.rng.seed = _seed
	seed(_seed)
	_load_known_issues()
	# The pause menu opens on a window focus loss (UX-07): a windowed run's window loses focus to the machine, not to the sections.
	var pause_script: Variant = load("res://scripts/ui/pause_menu.gd")
	if pause_script is GDScript:
		(pause_script as GDScript).set("auto_pause", false)
	var isolated := OS.get_environment("PLAYTEST_ISOLATED") == "1"
	print("PLAYTEST start mode=%s character=%s sections=%s only=%s" % ["windowed" if _windowed else "headless", _character, _sections_dir, ",".join(_only) if not _only.is_empty() else "*"])
	print("  info  user dir %s (%s)" % [_t.user_dir, "throwaway" if isolated else "REAL user dir: run tests/run_playtest.sh for an isolated one"])
	process_frame.connect(_check_run_watchdog)
	_run.call_deferred()


## tests/lib/known_issues.txt: "<substring><TAB><reason>" per line (# comments). A message containing the substring
## is a KNOWN issue of the current tree: listed in every run, not a failure. --strict switches this off.
func _load_known_issues() -> void:
	if _strict:
		print("  info  --strict: known issues are not tolerated")
		return
	for path in _known_paths:
		if not FileAccess.file_exists(path):
			continue
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		while not f.eof_reached():
			var line := f.get_line().strip_edges()
			if line == "" or line.begins_with("#"):
				continue
			var parts := line.split("\t", false, 1)
			_catcher.add_known(parts[0].strip_edges(), (parts[1].strip_edges() if parts.size() > 1 else "known issue"), path)
		f.close()
	if not _catcher.known_rules.is_empty():
		print("  info  %d known issue(s) of this tree are tolerated and listed as KNOWN (tests/lib/known_issues.txt; --strict ignores them)" % _catcher.known_rules.size())


## The watchdogs count WALL-CLOCK time (Time.get_ticks_msec), not game time: with `run_playtest.sh --fast` (--fixed-fps 60) a frame costs a fraction of a
## millisecond and a game second passes in a few, so a SceneTreeTimer of 240 "seconds" would trip on a section that waits on the wall clock
## (UiAudit's settle loops) long before the section is stuck. Checked once per frame, like the timer it replaces.
func _check_run_watchdog() -> void:
	if _finished or float(Time.get_ticks_msec() - _t0) / 1000.0 <= _max_seconds:
		return
	process_frame.disconnect(_check_run_watchdog)
	_on_global_timeout()


func _on_global_timeout() -> void:
	if _finished:
		return
	_problems.append("the whole run exceeded --max-seconds=%d" % int(_max_seconds))
	print("  FAIL  run watchdog: the whole run exceeded %d s" % int(_max_seconds))
	_finish()


# ---------------------------------------------------------------- main flow

func _run() -> void:
	await process_frame                  # autoload _ready() has run
	if DisplayServer.get_name() == "headless":
		root.size = WINDOW_SIZE          # the dummy window is 64x64: UI layout and GUI clicks need the design size
	_discover()
	if _usage_error:
		return
	if _list:
		_print_list()
		quit(1 if not _problems.is_empty() else 0)
		return
	if not _problems.is_empty():
		_finish()                   # a section does not compile: fail at once, run nothing
		return
	if _windowed:
		await _prepare_window()
		if not _problems.is_empty():
			_finish()
			return
	if _boot_mode == "yes" or (_boot_mode == "auto" and not _windowed):
		await _boot_stage()
	for s in _sections:
		if _aborted:
			break
		if not s["selected"]:
			continue
		await _run_section(s)
	_finish()


func _prepare_window() -> void:
	if DisplayServer.get_name() == "headless":
		_problems.append("--windowed needs a display: do not combine it with --headless")
		return
	# The harness owns the window: the title's saved / default window (SettingsUI.apply_window, KEEP_WINDOW) must not resize it.
	root.set_meta(&"tt_keep_window", true)
	if Vector2i(root.size) != WINDOW_SIZE:
		DisplayServer.window_set_size(WINDOW_SIZE)
		await process_frame
		await process_frame
	print("  info  window %dx%d (%s)" % [root.size.x, root.size.y, DisplayServer.get_name()])
	if _out != "":
		print("  info  screenshots go to ", _out)


func _boot_stage() -> void:
	_begin_section("boot")
	print("== boot (%s): main_menu -> character_select -> world" % _character)
	var mark: int = _catcher.mark()
	var done: bool = await _guarded(60.0, func() -> void:
		await _t.boot(_character)
		await _t.seconds(_play_seconds))
	_end_section(mark)
	if not done:
		_timeout_abort("boot", 60.0)


func _run_section(s: Dictionary) -> void:
	var name_: String = s["name"]
	var method := "run_windowed" if _windowed else "run"
	if not (s["has_win"] if _windowed else s["has_run"]):
		print("== section %s: no %s(t), skipped" % [name_, method])
		return
	if _windowed:
		await _t.clear_scene()   # sections must not see the world of the section before them (lead fix: windowed isolation)
	# A section may deliberately visit all races. Its local choice must not
	# change the default selected by --character for subsequent sections.
	_t.character = _character
	_begin_section(name_)
	_t.stats[name_]["character"] = _t.character
	print("== section %s%s  (%s)" % [name_, " [windowed]" if _windowed else "", s["path"]])
	var obj: Object = (s["script"] as GDScript).new()
	var mark: int = _catcher.mark()
	var limit := float(s["timeout"])
	var done: bool = await _guarded(limit, func() -> void:
		if _windowed:
			await obj.run_windowed(_t)
		else:
			await obj.run(_t))
	var script_err: String = _catcher.script_error_since(mark)
	if done and script_err != "":
		print("  note  the script error above ended this section early: the checks after it did not run")
	_end_section(mark)
	_ran.append(name_)
	if not done:
		_timeout_abort(name_, limit)
	elif float(_t.stats[name_]["ms"]) / 1000.0 > SLOW_SECTION_S:
		print("  note  section %s took %.1f s (> %d s): consider splitting it" % [name_, float(_t.stats[name_]["ms"]) / 1000.0, int(SLOW_SECTION_S)])
	if obj is Node:
		(obj as Node).queue_free()


## Runs `work` (a coroutine Callable) and waits for it, but at most `limit` WALL-CLOCK seconds (see _check_run_watchdog). Returns false on timeout.
## A coroutine that is stuck forever cannot be cancelled in GDScript, so a timeout aborts the whole run.
func _guarded(limit: float, work: Callable) -> bool:
	_guard_done = false
	var started := Time.get_ticks_msec()
	_guard_run(work)
	while not _guard_done and float(Time.get_ticks_msec() - started) / 1000.0 < limit:
		await process_frame
	return _guard_done


func _guard_run(work: Callable) -> void:
	await work.call()
	_guard_done = true


func _timeout_abort(what: String, limit: float) -> void:
	var msg := "section %s timed out after %d s (a coroutine is still waiting; look for an await on something that never happens)" % [what, int(limit)]
	_problems.append(msg)
	print("  FAIL  ", msg)
	var pending: Array[String] = []
	for s in _sections:
		if s["selected"] and s["name"] != what and s["name"] not in _ran:
			pending.append(s["name"])
	if not pending.is_empty():
		print("  note  not run because of the timeout: ", ", ".join(pending))
	_aborted = true


func _begin_section(name_: String) -> void:
	_t.begin_section(name_)
	_catcher.section = name_
	_catcher.clear_allow()


func _end_section(mark: int) -> void:
	_t.end_section()
	var st: Dictionary = _t.stats.get(_t.section, {})
	print("  --    %s: %d checks, %d failed, %d skipped, %.1f s" % [_t.section, int(st.get("checks", 0)), int(st.get("failed", 0)), int(st.get("skipped", 0)), float(st.get("ms", 0)) / 1000.0])
	_t.release_all()
	if Engine.time_scale != 1.0:
		print("  note  section %s left Engine.time_scale at %s; reset to 1" % [_t.section, Engine.time_scale])
		Engine.time_scale = 1.0
	if paused:
		print("  note  section %s left the tree paused; unpaused" % _t.section)
		paused = false
	for rule in _catcher.allow_hits.keys():
		if int(_catcher.allow_hits[rule]) == 0:
			print("  note  allow('%s') was declared but the message never appeared" % rule)
	for m in _catcher.since(mark):
		print("  ENGINE ", m)
	_catcher.clear_allow()
	_catcher.section = "-"


# ---------------------------------------------------------------- discovery

func _discover() -> void:
	var dir := DirAccess.open(_sections_dir)
	if dir == null:
		if _sections_dir == DEFAULT_SECTIONS_DIR:
			print("  info  %s does not exist yet: no sections" % _sections_dir)
		else:
			_problems.append("sections directory %s does not exist" % _sections_dir)
			print("  FAIL  ", _problems[-1])
		return
	var files: Array[String] = []
	for f in dir.get_files():
		if f.ends_with(".gd") and not f.begins_with("_"):
			files.append(f)
	files.sort()
	var seen_names := {}
	for f in files:
		var path := _sections_dir.path_join(f)
		var base := f.get_basename()
		_catcher.capture_begin()
		var script: Variant = load(path)
		var captured: Array = _catcher.capture_end()
		var entry := {"base": base, "name": base, "path": path, "script": null, "compiled": false, "has_run": false, "has_win": false, "timeout": _section_timeout, "selected": false, "error": ""}
		if script is GDScript and (script as GDScript).can_instantiate():
			var gd := script as GDScript
			entry["script"] = gd
			entry["compiled"] = true
			var consts := gd.get_script_constant_map()
			if consts.has("SECTION"):
				entry["name"] = str(consts["SECTION"])
			if consts.has("TIMEOUT_S"):
				entry["timeout"] = float(consts["TIMEOUT_S"])
			for m in gd.get_script_method_list():
				if m["name"] == "run":
					entry["has_run"] = true
				elif m["name"] == "run_windowed":
					entry["has_win"] = true
		else:
			entry["error"] = captured[0]["text"] if not captured.is_empty() else "load() returned no usable script"
		entry["selected"] = _only.is_empty() or base in _only or (entry["compiled"] and entry["name"] in _only)
		if entry["selected"]:
			_catcher.commit(captured, base)
		if not entry["compiled"]:
			if entry["selected"]:
				_problems.append("section %s does not compile: %s" % [path, entry["error"]])
				print("  FAIL  ", _problems[-1])
			else:
				print("  note  %s does not compile (not selected by --only, ignored): %s" % [path, str(entry["error"]).left(160)])
		elif not entry["has_run"] and not entry["has_win"]:
			if entry["selected"]:
				_problems.append("%s is not a section: it defines neither run(t) nor run_windowed(t)" % path)
				print("  FAIL  ", _problems[-1])
		elif seen_names.has(entry["name"]):
			_problems.append("sections %s and %s both declare SECTION \"%s\"" % [seen_names[entry["name"]], path, entry["name"]])
			print("  FAIL  ", _problems[-1])
		else:
			seen_names[entry["name"]] = path
		_sections.append(entry)
	_sections.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["base"] < b["base"])
	# --only must name real sections (a typo must not turn into a green run that checked nothing)
	for want in _only:
		var matched := false
		for s in _sections:
			if want == s["base"] or (s["compiled"] and want == s["name"]):
				matched = true
				if _windowed and not s["has_win"] and s["compiled"]:
					_problems.append("--only=%s names a section without run_windowed(t)" % want)
					print("  FAIL  ", _problems[-1])
		if not matched:
			var known: Array[String] = []
			for s in _sections:
				known.append(s["name"])
			print("PLAYTEST usage error: --only names unknown section '%s' (known: %s)" % [want, ", ".join(known) if not known.is_empty() else "none"])
			_usage_error = true
			quit(2)
			return


func _print_list() -> void:
	print("PLAYTEST list of %s%s" % [_sections_dir, " (windowed sections only)" if _windowed else ""])
	var n := 0
	for s in _sections:
		if not s["selected"]:
			continue
		if not s["compiled"]:
			print("  !! %-18s %s   DOES NOT COMPILE: %s" % [s["base"], s["path"], str(s["error"]).left(120)])
			continue
		if _windowed and not s["has_win"]:
			continue
		var kinds: Array[String] = []
		if s["has_run"]:
			kinds.append("run")
		if s["has_win"]:
			kinds.append("run_windowed")
		print("  %-20s %s   [%s]%s" % [s["name"], s["path"], " ".join(kinds), "  timeout %ds" % int(s["timeout"]) if s["timeout"] != _section_timeout else ""])
		n += 1
	print("PLAYTEST list end: %d section(s)%s" % [n, ", %d problem(s)" % _problems.size() if not _problems.is_empty() else ""])


# ---------------------------------------------------------------- result

func _finish() -> void:
	if _finished or _t == null:
		return
	_finished = true
	paused = true
	var audio := root.get_node_or_null("AudioManager")
	if audio!=null and audio.has_method("prepare_shutdown"):await audio.prepare_shutdown()
	var engine_n: int = _catcher.mark()
	var errors: int = engine_n - _catcher.count_kind("warning")
	var warnings: int = _catcher.count_kind("warning")
	var bad: int = int(_t.failed) + engine_n + _problems.size()
	var elapsed := float(Time.get_ticks_msec() - _t0) / 1000.0
	print("== summary: %d section(s) run, %d checks (%d failed, %d skipped), %d engine error(s), %d engine warning(s), %d allowed message(s), %d problem(s), %d known-issue message(s), %.1f s" % [
		_ran.size(), _t.checks, _t.failed, _t.skipped, errors, warnings, _catcher.allowed_entries.size(), _problems.size(), _catcher.known_entries.size(), elapsed])
	for f in _t.failures:
		print("  FAILED   ", f)
	var on_actions := OS.get_environment("GITHUB_ACTIONS") == "true"
	for s in _t.slow:
		print("  SLOW     %s: %s, native reference %s (%.2fx, passed inside the runner limit %s)" % [s.check, s.measured, s.reference, s.ratio, s.limit])
		if on_actions:
			print("::notice title=Slow timing (%s)::%s took %s against a native reference of %s (%.2fx); the runner limit is %s" % [_character, s.check, s.measured, s.reference, s.ratio, s.limit])
	for p in _problems:
		print("  PROBLEM  ", p)
	for rule in _catcher.known_rules:
		var hits: int = int(_catcher.known_rules[rule]["hits"])
		if hits > 0:
			print("  KNOWN    %dx '%s': %s" % [hits, rule, _catcher.known_rules[rule]["reason"]])
		else:
			print("  note     known issue '%s' did not occur: resolved? remove it from %s" % [rule, _catcher.known_rules[rule]["source"]])
	var shown := 0
	for m in _catcher.since(0):
		if shown >= 20:
			print("  ENGINE   ... %d more" % (engine_n - shown))
			break
		print("  ENGINE   ", m)
		shown += 1
	if _report != "":
		_write_report(bad == 0, elapsed)
	if bad == 0:
		print("PLAYTEST PASS (%d checks in %d sections, %d allowed engine messages, %d known-issue messages)" % [_t.checks, _ran.size(), _catcher.allowed_entries.size(), _catcher.known_entries.size()])
	else:
		print("PLAYTEST FAIL: %d check failures, %d engine errors, %d engine warnings, %d problems" % [_t.failed, errors, warnings, _problems.size()])
	quit(0 if bad == 0 else 1)


func _write_report(passed: bool, elapsed: float) -> void:
	var engine: Array = []
	for e in _catcher.entries:
		engine.append(e)
	var data := {
		"result": "pass" if passed else "fail",
		"mode": "windowed" if _windowed else "headless",
		"character": _character,
		"elapsed_s": snappedf(elapsed, 0.01),
		"checks": _t.checks,
		"failed": _t.failed,
		"skipped": _t.skipped,
		"sections": _t.stats,
		"failures": _t.failures,
		"slow": _t.slow,
		"problems": _problems,
		"engine": engine,
		"allowed": _catcher.allowed_entries,
		"known": _catcher.known_entries,
	}
	var f := FileAccess.open(_report, FileAccess.WRITE)
	if f == null:
		print("  note  could not write the report to %s (error %d)" % [_report, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify(data, "  "))
	f.close()


# ---------------------------------------------------------------- command line

func _parse_args(args: PackedStringArray) -> String:
	for a in args:
		if a.begins_with("--character="):
			_character = a.get_slice("=", 1)
			if _character not in ["animal", "fairy", "hobbit", "ghost"]:
				return "--character must be animal, fairy, hobbit or ghost (got '%s')" % _character
		elif a.begins_with("--only="):
			for n in a.get_slice("=", 1).split(",", false):
				_only.append(n.strip_edges())
		elif a == "--list":
			_list = true
		elif a == "--windowed":
			_windowed = true
		elif a.begins_with("--out="):
			_out = _absolute(a.get_slice("=", 1))
			DirAccess.make_dir_recursive_absolute(_out)
		elif a == "--no-boot":
			_boot_mode = "no"
		elif a == "--boot":
			_boot_mode = "yes"
		elif a.begins_with("--play-seconds="):
			_play_seconds = float(a.get_slice("=", 1))
		elif a.begins_with("--scenario="):
			if a.get_slice("=", 1) != "flow":
				return "unknown scenario '%s' (only 'flow' exists)" % a.get_slice("=", 1)
		elif a.begins_with("--sections-dir="):
			var d := a.get_slice("=", 1).rstrip("/")
			_sections_dir = d if d.begins_with("res://") or d.begins_with("user://") else "res://" + d
		elif a.begins_with("--section-timeout="):
			_section_timeout = float(a.get_slice("=", 1))
		elif a.begins_with("--max-seconds="):
			_max_seconds = float(a.get_slice("=", 1))
		elif a.begins_with("--report="):
			_report = _absolute(a.get_slice("=", 1))
		elif a.begins_with("--seed="):
			_seed = int(a.get_slice("=", 1))
		elif a == "--verbose":
			_verbose = true
		elif a == "--strict":
			_strict = true
		elif a == "--fast":
			_fast = true
		elif a.begins_with("--known-issues="):
			var kp := a.get_slice("=", 1)
			_known_paths.append(kp if kp.begins_with("res://") or kp.begins_with("user://") else "res://" + kp)
		elif a == "--help" or a == "-h":
			_help = true
		else:
			return "unknown option '%s'" % a
	return ""


func _absolute(path: String) -> String:
	if path.is_absolute_path():
		return path
	return ProjectSettings.globalize_path("res://").path_join(path)


func _print_usage() -> void:
	print("usage: tests/run_playtest.sh [--character=animal|fairy|hobbit|ghost] [--only=a,b] [--list] [--windowed] [--out=DIR]")
	print("       [--no-boot] [--play-seconds=N] [--section-timeout=N] [--max-seconds=N] [--report=FILE] [--seed=N] [--verbose] [--strict] [--fast]")
	print("       wrapper only (tests/run_playtest.sh): [--fast] [--no-import] [--timeout=SECS] [--keep-home]")
