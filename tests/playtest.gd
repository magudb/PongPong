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
##   --shuffle=N                       run the selected sections in an order shuffled with seed N (finds sections that depend on what
##                                     an earlier one left behind; the nightly CI run uses it); the order is printed
##   --strict                          ignore tests/lib/known_issues.txt: every engine message fails the run, a section may not skip
##                                     more checks than tests/lib/skip_budget.txt allows, and t.require_tool() fails instead of skipping
##   --known-issues=PATH               one more known-issues file besides res://tests/lib/known_issues.txt (repeatable)
##   --skip-budget=PATH                the skip budget file instead of res://tests/lib/skip_budget.txt (also for --sections-dir runs)
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
## Isolation between sections (they share one process): after every section the harness runs its t.on_cleanup() callables,
## releases held input, resets Engine.time_scale and the pause, and puts back what the section changed and did not restore
## itself (a note names each): the locale, GameManager config overrides, Svc fakes, the modal stack, Engine metadata (the
## sections' probe channel) and the String *_path / *_dir seams of the autoloads. A section that times out fails the run, but the next sections
## still run: its `t` is detached (its wait helpers park the stuck coroutine for good), the scene is cleared, and the rest of the
## run gets a fresh `t`. Only the boot stage and --max-seconds stop a run early.
##
## This script compiles BEFORE the autoloads exist: it never names an autoload (tests/lib reaches them with
## root.get_node) and loads its libraries with load().

const LIB := "res://tests/lib/"
const DEFAULT_SECTIONS_DIR := "res://tests/sections"
const WINDOW_SIZE := Vector2i(1280, 720)
const SLOW_SECTION_S := 30.0
const SKIP_BUDGET := "res://tests/lib/skip_budget.txt"

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
var _known_paths: Array[String] = ["res://tests/lib/known_issues.txt"]
var _shuffle := -1                       # --shuffle=N seed; -1 = alphabetical order
var _skip_budget: Dictionary = {}        # section -> skips allowed under --strict (tests/lib/skip_budget.txt)
var _skip_budget_on := false
var _skip_budget_path := SKIP_BUDGET     # --skip-budget=PATH (the harness self-test's fixtures)

var _t0 := 0
var _problems: Array[String] = []        # run-level failures that are not checks (compile errors, timeouts, ...)
var _sections: Array[Dictionary] = []    # discovered: {base, name, path, script, compiled, has_run, has_win, timeout, selected}
var _ran: Array[String] = []
var _aborted := false                    # a timeout stopped the run
var _finished := false
var _usage_error := false
var _help := false


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
	_t = _make_t(t_script as GDScript)
	seed(_seed)
	_load_known_issues()
	_load_skip_budget()
	# The pause menu opens on a window focus loss (UX-07): a windowed run's window loses focus to the machine, not to the sections.
	var pause_script: Variant = load("res://scripts/ui/pause_menu.gd")
	if pause_script is GDScript:
		(pause_script as GDScript).set("auto_pause", false)
	var isolated := OS.get_environment("PLAYTEST_ISOLATED") == "1"
	print("PLAYTEST start mode=%s character=%s sections=%s only=%s" % ["windowed" if _windowed else "headless", _character, _sections_dir, ",".join(_only) if not _only.is_empty() else "*"])
	print("  info  user dir %s (%s)" % [_t.user_dir, "throwaway" if isolated else "REAL user dir: run tests/run_playtest.sh for an isolated one"])
	process_frame.connect(_check_run_watchdog)
	_run.call_deferred()


## A `t` configured for this run (the run's first one, and the fresh one after a section timed out).
func _make_t(t_script: GDScript) -> Object:
	var t: Object = t_script.new()
	t.bind(self)
	t.catcher = _catcher
	t.character = _character
	t.windowed = _windowed
	t.out_dir = _out
	t.verbose = _verbose
	t.strict = _strict
	t.user_dir = OS.get_user_data_dir()
	t.rng.seed = _seed
	return t


## tests/lib/skip_budget.txt: "<section><TAB><max skips><TAB><why>" per line (# comments). Applies to strict headless runs of the
## real sections: a section that skips more checks than its budget (0 when it has no line) fails the run, so a skip that
## spreads (a missing tool, a fixture that went missing) cannot hide a gate. Other runs only print a note.
func _load_skip_budget() -> void:
	_skip_budget_on = not _windowed and (_sections_dir == DEFAULT_SECTIONS_DIR or _skip_budget_path != SKIP_BUDGET)
	if not _skip_budget_on or not FileAccess.file_exists(_skip_budget_path):
		return
	var f := FileAccess.open(_skip_budget_path, FileAccess.READ)
	if f == null:
		return
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var parts := line.split("\t", false)
		if parts.size() >= 2 and parts[1].strip_edges().is_valid_int():
			_skip_budget[parts[0].strip_edges()] = int(parts[1].strip_edges())
	f.close()


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
	var before := _snapshot_state()
	var t: Object = _t
	var done: bool = await _guarded(limit, func() -> void:
		if _windowed:
			await obj.run_windowed(t)
		else:
			await obj.run(t))
	var script_err: String = _catcher.script_error_since(mark)
	if done and script_err != "":
		print("  note  the script error above ended this section early: the checks after it did not run")
	if not await _guarded(10.0, func() -> void: await t.run_cleanups()):
		print("  FAIL  the t.on_cleanup() callables of %s did not finish within 10 s" % name_)
		_problems.append("the cleanups of section %s did not finish within 10 s" % name_)
	_check_skip_budget(name_)
	_end_section(mark)
	_ran.append(name_)
	if not done:
		await _isolate_timeout(name_, limit)
	elif float(_t.stats[name_]["ms"]) / 1000.0 > SLOW_SECTION_S:
		print("  note  section %s took %.1f s (> %d s): consider splitting it" % [name_, float(_t.stats[name_]["ms"]) / 1000.0, int(SLOW_SECTION_S)])
	_restore_state(before, name_)
	if obj is Node and done:
		(obj as Node).queue_free()


## Runs `work` (a coroutine Callable) and waits for it, but at most `limit` WALL-CLOCK seconds (see _check_run_watchdog). Returns false on timeout.
## A coroutine that is stuck cannot be cancelled in GDScript: each call has its own done flag, so a stuck one that finishes
## later cannot end the wait of a later section (see _isolate_timeout).
func _guarded(limit: float, work: Callable) -> bool:
	var box := {"done": false}
	var started := Time.get_ticks_msec()
	_guard_run(work, box)
	while not box["done"] and float(Time.get_ticks_msec() - started) / 1000.0 < limit:
		await process_frame
	return box["done"]


func _guard_run(work: Callable, box: Dictionary) -> void:
	await work.call()
	box["done"] = true


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


## A section timed out: it fails the run, and the run goes on with the next section. The stuck coroutine keeps the old `t`,
## which is detached (its frames / physics / seconds / until park the coroutine for good when it wakes up), the scene it left is
## freed, and the next sections get a fresh `t` that carries the run's counts on.
func _isolate_timeout(what: String, limit: float) -> void:
	var msg := "section %s timed out after %d s (a coroutine is still waiting; look for an await on something that never happens)" % [what, int(limit)]
	_problems.append(msg)
	print("  FAIL  ", msg)
	var old: Object = _t
	old.detached = true
	old.release_all()
	var fresh: Object = _make_t(old.get_script() as GDScript)
	fresh.checks = old.checks
	fresh.failed = old.failed
	fresh.skipped = old.skipped
	fresh.failures = old.failures
	fresh.slow = old.slow
	fresh.stats = old.stats
	_t = fresh
	await _t.clear_scene()
	print("  note  the next sections still run: the stuck section is parked, its scene was freed")


## What a section may change for its own checks and must leave as it found it (see the header). Taken before every section.
func _snapshot_state() -> Dictionary:
	var gm := root.get_node_or_null("GameManager")
	var loc := root.get_node_or_null("LocalizationManager")
	var overrides: Variant = gm.get("_config_overrides") if gm != null else null
	var svc_fakes: Variant = _svc_script().get("_overrides") if _svc_script() != null else null
	return {
		"locale": str(loc.get("current_locale")) if loc != null else TranslationServer.get_locale(),
		"overrides": (overrides as Dictionary).duplicate() if overrides is Dictionary else {},
		"svc": (svc_fakes as Dictionary).duplicate() if svc_fakes is Dictionary else {},
		"engine_meta": _metas(Engine),
		"seams": _seams(),
	}


## Puts back what the section changed and did not restore itself; prints a note for each kind (a section should use t.on_cleanup()).
func _restore_state(before: Dictionary, section_name: String) -> void:
	var fixed: Array[String] = []
	var gm := root.get_node_or_null("GameManager")
	var loc := root.get_node_or_null("LocalizationManager")
	if loc != null and str(loc.get("current_locale")) != str(before["locale"]):
		fixed.append("locale %s -> %s" % [loc.get("current_locale"), before["locale"]])
		loc.call("set_locale", str(before["locale"]), false)
	if gm != null and gm.get("_config_overrides") is Dictionary and gm.get("_config_overrides") != before["overrides"]:
		fixed.append("config overrides")
		gm.call("clear_config_overrides")
		for path in (before["overrides"] as Dictionary):
			gm.call("set_config_override", path, before["overrides"][path])
	var svc := _svc_script()
	if svc != null and svc.get("_overrides") is Dictionary and svc.get("_overrides") != before["svc"]:
		fixed.append("Svc fakes")
		svc.call("clear_overrides")
		for key in (before["svc"] as Dictionary):
			if is_instance_valid(before["svc"][key]):
				svc.call("override", key, before["svc"][key])
	if gm != null and gm.has_method("is_modal_open") and gm.call("is_modal_open"):
		fixed.append("open modals %s" % str(gm.call("modal_stack")))
		gm.call("pop_all_modals")
		paused = false
	var metas := _restore_metas(Engine, before["engine_meta"])
	if not metas.is_empty():
		fixed.append("Engine meta %s" % ", ".join(metas))
	var seams: Dictionary = before["seams"]
	for key in seams:
		var parts := str(key).split(".")
		var node := root.get_node_or_null(parts[0])
		if node != null and node.get(parts[1]) != seams[key]:
			fixed.append("%s = %s" % [key, seams[key]])
			node.set(parts[1], seams[key])
	if not fixed.is_empty():
		print("  note  section %s left state behind; restored: %s (use t.on_cleanup)" % [section_name, "; ".join(fixed)])


func _svc_script() -> Script:
	var svc: Variant = load("res://scripts/data/svc.gd") if ResourceLoader.exists("res://scripts/data/svc.gd") else null
	return svc as Script


func _metas(o: Object) -> Dictionary:
	var out := {}
	for m in o.get_meta_list():
		out[m] = o.get_meta(m)
	return out


## Removes metadata the section added and puts back values it changed; returns the names.
func _restore_metas(o: Object, before: Dictionary) -> Array[String]:
	var changed: Array[String] = []
	for m in o.get_meta_list():
		if not before.has(m):
			o.remove_meta(m)
			changed.append(str(m))
		elif typeof(o.get_meta(m)) != typeof(before[m]) or o.get_meta(m) != before[m]:
			o.set_meta(m, before[m])
			changed.append(str(m))
	for m in before:
		if not o.has_meta(m):
			o.set_meta(m, before[m])
			changed.append(str(m))
	return changed


## "Autoload.property" -> value of every String script variable named *_path or *_dir of the autoloads (fixture seams such as
## LootService.delegate_path or SaveManager.save_dir).
func _seams() -> Dictionary:
	var out := {}
	for n in root.get_children():
		if n == current_scene or n.get_script() == null:
			continue
		for p in n.get_property_list():
			var pname := str(p["name"])
			if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE and int(p["type"]) == TYPE_STRING and (pname.ends_with("_path") or pname.ends_with("_dir")):
				out["%s.%s" % [n.name, pname]] = n.get(pname)
	return out


## Under --strict (headless, real sections) a section may skip at most its budget of tests/lib/skip_budget.txt.
func _check_skip_budget(name_: String) -> void:
	if not _skip_budget_on:
		return
	var n := int(_t.stats.get(name_, {}).get("skipped", 0))
	var budget := int(_skip_budget.get(name_, 0))
	if n <= budget:
		return
	var msg := "section %s skipped %d check(s), its budget is %d (%s): a skip that spreads hides a gate" % [name_, n, budget, _skip_budget_path.trim_prefix("res://")]
	if _strict:
		_problems.append(msg)
		print("  FAIL  ", msg)
	else:
		print("  note  ", msg, " (fails under --strict)")


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
	if _shuffle >= 0:
		var order := RandomNumberGenerator.new()
		order.seed = _shuffle
		for i in range(_sections.size() - 1, 0, -1):
			var j := order.randi_range(0, i)
			var tmp: Dictionary = _sections[i]
			_sections[i] = _sections[j]
			_sections[j] = tmp
		var names: Array[String] = []
		for s in _sections:
			if s["selected"]:
				names.append(s["name"])
		print("  info  --shuffle=%d: sections run in this order: %s" % [_shuffle, ", ".join(names)])
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
		elif a.begins_with("--shuffle="):
			if not a.get_slice("=", 1).is_valid_int() or int(a.get_slice("=", 1)) < 0:
				return "--shuffle needs a seed >= 0 (got '%s')" % a.get_slice("=", 1)
			_shuffle = int(a.get_slice("=", 1))
		elif a == "--verbose":
			_verbose = true
		elif a == "--strict":
			_strict = true
		elif a.begins_with("--skip-budget="):
			var sb := a.get_slice("=", 1)
			_skip_budget_path = sb if sb.begins_with("res://") or sb.begins_with("user://") else "res://" + sb
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
	print("       [--no-boot] [--play-seconds=N] [--section-timeout=N] [--max-seconds=N] [--report=FILE] [--seed=N] [--shuffle=N] [--verbose] [--strict]")
	print("       wrapper only (tests/run_playtest.sh): [--fast] [--no-import] [--timeout=SECS] [--keep-home]")
