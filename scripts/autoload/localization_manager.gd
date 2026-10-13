extends Node
## Runtime CSV localization (PLAN 3.4, decision D6): no import step, no .translation files.
##
## _ready() (an autoload runs before any scene) loads every res://localization/*.csv (header `keys,da,en`):
## da.csv first (the legacy base), then every other CSV alphabetically; later files override earlier keys.
## One Translation per locale is added to the TranslationServer. A key must match ^[A-Z0-9_]+$.
## The saved locale lives in user://settings.cfg [game] locale (shared file: load-modify-save, other sections are kept).
##
## Scenes hold KEYS as `text`: Label/Button/LineEdit translate automatically and follow locale changes.
## Text assembled in code uses t(key, args) - it never applies `%` to an untranslated key.
##
## lint() (and tests/loc_check.gd, tools/loc/csv_lint.py - the same rules) reports:
##   [header] [malformed] [duplicate] [missing-text] [format] [keep-import] [ownership] [voiced]  (errors)
##   the same problems inside the LEGACY da.csv are "legacy" issues: tolerated until P26 prunes the file, fatal under --strict.
##
## No `class_name` (it would clash with the autoload name). The static functions are reusable by tools:
##   const LM := preload("res://scripts/autoload/localization_manager.gd")  ->  LM.parse_dir(...), LM.lua_parse(...)

signal locale_changed(locale: String)

const LOCALE_DA := "da"
const LOCALE_EN := "en"
const DEFAULT_LOCALE := "da"
const FALLBACK_LOCALE := "en"
const LOCALES: PackedStringArray = ["da", "en"]

const LOC_DIR := "res://localization"
const LEGACY_FILE := "da.csv"
const FINAL_FILE := "zz_final.csv"
const OWNERS_PATH := "tools/loc/key_owners.json"
const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "game"
const SETTINGS_KEY := "locale"

## Current locale ("da" | "en"). Read-only for callers: change it with set_locale().
var current_locale: String = DEFAULT_LOCALE

var _translations: Array[Translation] = []
var _rows: Dictionary = {}          # key -> {file: String, line: int, text: {locale: String}} (effective, after overrides)
var _files: PackedStringArray = PackedStringArray()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	boot()


# ---------------------------------------------------------------- loading and locale

## (Re)loads every CSV and applies the saved locale. No toast, no signal, nothing is written.
## _ready() calls it; tests and dev tools may call it again (translations are replaced, never doubled).
func boot() -> void:
	_load_translations()
	_apply_locale(_saved_locale())


## Re-reads the CSVs after an edit (dev) and keeps the current locale.
func reload() -> void:
	_load_translations()
	_apply_locale(current_locale)


func _load_translations() -> void:
	for t_old in _translations:
		TranslationServer.remove_translation(t_old)
	_translations.clear()
	var parsed := parse_dir(LOC_DIR)
	_rows = parsed["rows"]
	_files = parsed["files"]
	if _files.is_empty():
		push_error("LocalizationManager: no *.csv files found in %s - every text will show its raw key" % LOC_DIR)
	var per_locale: Dictionary = {}
	for key in _rows:
		var texts: Dictionary = (_rows[key] as Dictionary)["text"]
		for loc in texts:
			if not per_locale.has(loc):
				var tr_new := Translation.new()
				tr_new.locale = loc
				per_locale[loc] = tr_new
			(per_locale[loc] as Translation).add_message(StringName(key), StringName(texts[loc]))
	for loc in per_locale:
		var tr_add: Translation = per_locale[loc]
		TranslationServer.add_translation(tr_add)
		_translations.append(tr_add)


func _apply_locale(locale: String) -> void:
	current_locale = locale
	TranslationServer.set_locale(locale)


static func _saved_locale() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return DEFAULT_LOCALE
	var loc := normalize_locale(str(cfg.get_value(SETTINGS_SECTION, SETTINGS_KEY, DEFAULT_LOCALE)))
	return DEFAULT_LOCALE if loc == "" else loc


static func _persist_locale(locale: String) -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("LocalizationManager: %s is unreadable (error %d); the language choice was not saved so that no other setting is destroyed" % [SETTINGS_PATH, err])
		return
	cfg.set_value(SETTINGS_SECTION, SETTINGS_KEY, locale)
	var save_err := cfg.save(SETTINGS_PATH)
	if save_err != OK:
		push_warning("LocalizationManager: could not write %s (error %d)" % [SETTINGS_PATH, save_err])


## "da", "da_DK", "DA-dk" -> "da"; anything that is not a supported locale -> "".
static func normalize_locale(locale: String) -> String:
	var base := locale.strip_edges().to_lower().replace("-", "_").get_slice("_", 0)
	return base if base in LOCALES else ""


## Switches the language, persists the choice and emits locale_changed (only when the locale really changed).
## `announce` shows the "language changed" toast (never at boot: boot() does not go through here).
func set_locale(locale: String, announce: bool = true) -> void:
	var loc := normalize_locale(locale)
	if loc == "":
		push_warning("LocalizationManager.set_locale: unsupported locale '%s' (supported: %s)" % [locale, ", ".join(LOCALES)])
		return
	var changed := loc != current_locale
	_apply_locale(loc)
	_persist_locale(loc)
	if changed:
		locale_changed.emit(loc)
		if announce:
			_announce_language()


func _announce_language() -> void:
	var bus := get_node_or_null("/root/EventBus")
	if bus == null or not bus.has_signal("notification_posted"):
		return
	bus.emit_signal("notification_posted",
		TranslationServer.translate(&"NOTIF_LANGUAGE_CHANGED_TITLE"),
		t("NOTIF_LANGUAGE_CHANGED_MSG", [language_name(current_locale)]),
		"language")


func is_da() -> bool:
	return current_locale == LOCALE_DA


func is_en() -> bool:
	return current_locale == LOCALE_EN


## Name of a language in that language ("dansk" / "English"); keys LANG_DA / LANG_EN (core.csv).
func language_name(locale: String = "") -> String:
	var loc := current_locale if locale == "" else normalize_locale(locale)
	return text_in("LANG_" + loc.to_upper(), loc)


# ---------------------------------------------------------------- lookups

## Translated text of `key` in the current locale. `args` fills the % placeholders - but an untranslated key
## is returned untouched (never formatted), and a wrong argument count warns instead of raising an engine error.
func t(key: String, args: Array = []) -> String:
	var text := String(TranslationServer.translate(StringName(key)))
	if text == key or args.is_empty():
		return text
	var wanted := format_arg_count(text)
	if wanted != args.size():
		push_warning("LocalizationManager.t: '%s' (%s) takes %d argument(s), got %d" % [key, text, wanted, args.size()])
		return text
	return text % args


## True when `key` has a text in the current locale or in the fallback locale (t() would not return the raw key).
func has_key(key: String) -> bool:
	return text_in(key, current_locale) != "" or text_in(key, FALLBACK_LOCALE) != ""


## The raw (unescaped) CSV text of `key` in exactly this locale; "" when the key or that column is missing.
func text_in(key: String, locale: String) -> String:
	var row: Variant = _rows.get(key, null)
	if row == null:
		return ""
	return str((row as Dictionary)["text"].get(locale, ""))


## Every key the loader knows (load order). For the lint tool and tests.
func all_keys() -> PackedStringArray:
	return PackedStringArray(_rows.keys())


## CSV file names in load order (da.csv first).
func loaded_files() -> PackedStringArray:
	return _files


## Which CSV file defines the effective text of `key` ("" when unknown).
func file_of(key: String) -> String:
	var row: Variant = _rows.get(key, null)
	return "" if row == null else str((row as Dictionary)["file"])


## Lint report of the real localization folder: {files, key_count, errors, legacy, warnings}. Every issue is
## {cat, sev, file, line, key, msg}. `strict` moves the tolerated legacy (da.csv) issues into `errors`.
func lint(strict: bool = false) -> Dictionary:
	return summarize(parse_dir(LOC_DIR, "res://", true), strict)


# ---------------------------------------------------------------- voice (thin forwarder, PLAN R.14)

## Voice keys are paths below res://assets/audio/ ("voice/<npc_id>/<line_id>"). A line id that already is a full key
## ("voice/...") is returned as it is: no double prefix.
func voice_key_for(speaker_id: String, line_id: String) -> String:
	if line_id.begins_with("voice/"):
		return line_id
	return "voice/%s/%s" % [speaker_id, line_id]


## play_voice("voice/mayor_lyra/greet")  or  play_voice("mayor_lyra", "greet"). Everything else (the bus volume, the
## Danish-only rule, the stream lookup) belongs to AudioManager: this class keeps no second volume state.
func play_voice(key_or_speaker: String, line_id: String = "") -> void:
	var key := key_or_speaker if line_id == "" else voice_key_for(key_or_speaker, line_id)
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null and audio.has_method("play_voice"):
		audio.call("play_voice", key)


func voice_exists(key: String) -> bool:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null and audio.has_method("voice_exists"):
		return bool(audio.call("voice_exists", key))
	return false


# ================================================================ static: CSV parsing and lint (shared with tools)

static func is_valid_key(key: String) -> bool:
	if key.is_empty():
		return false
	for i in key.length():
		var c := key.unicode_at(i)
		if not ((c >= 65 and c <= 90) or (c >= 48 and c <= 57) or c == 95):
			return false
	return true


## CSV file names of a folder in load order: da.csv (legacy base) first, then the others alphabetically.
static func list_csv_files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var da := DirAccess.open(dir)
	if da == null:
		return out
	var names: Array[String] = []
	for f in da.get_files():
		if f.ends_with(".csv"):
			names.append(f)
	names.sort()
	if LEGACY_FILE in names:
		out.append(LEGACY_FILE)
		names.erase(LEGACY_FILE)
	out.append_array(PackedStringArray(names))
	return out


## \n \t \\ \" in a CSV text (what the old csv importer's unescape_translations did); other backslashes stay.
static func unescape_text(text: String) -> String:
	if not text.contains("\\"):
		return text
	var out := ""
	var i := 0
	while i < text.length():
		var ch := text[i]
		if ch == "\\" and i + 1 < text.length():
			var nx := text[i + 1]
			if nx == "n":
				out += "\n"
				i += 2
				continue
			if nx == "t":
				out += "\t"
				i += 2
				continue
			if nx == "\\" or nx == "\"":
				out += nx
				i += 2
				continue
		out += ch
		i += 1
	return out


static var _format_rx: RegEx = null


## Number of % conversions of a (translated) text, with `%%` excluded. Same rule as the engine's `text % array`.
static func format_signature(text: String) -> String:
	if not text.contains("%"):
		return ""
	if _format_rx == null:
		_format_rx = RegEx.new()
		_format_rx.compile("%[-+ #0]*(?:\\*|\\d+)?(?:\\.(?:\\*|\\d+))?([sdifxXoecv])")
	var found: Array[String] = []
	for m in _format_rx.search_all(text.replace("%%", "")):
		found.append(m.get_string(1))
	found.sort()
	return "".join(found)


static func format_arg_count(text: String) -> int:
	return format_signature(text).length()


static func make_issue(cat: String, sev: String, file: String, line: int, key: String, msg: String) -> Dictionary:
	return {"cat": cat, "sev": sev, "file": file, "line": line, "key": key, "msg": msg}


static func format_issue(iss: Dictionary) -> String:
	var where := str(iss.get("file", ""))
	if int(iss.get("line", 0)) > 0:
		where += ":%d" % int(iss["line"])
	var key := str(iss.get("key", ""))
	return "[%s] %s%s - %s" % [iss.get("cat", "?"), where, (" " + key) if key != "" else "", iss.get("msg", "")]


## Reads one CSV: {header: PackedStringArray, rows: [{line, cells}]}; {} when the file cannot be opened.
static func read_csv(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var header := f.get_csv_line()
	if header.size() > 0:
		header[0] = header[0].trim_prefix("\ufeff")
	var rows: Array[Dictionary] = []
	var line := 1
	for h in header:
		line += h.count("\n")
	while not f.eof_reached():
		var cells := f.get_csv_line()
		line += 1
		var row_line := line
		for c in cells:
			line += c.count("\n")
		if cells.size() <= 1 and (cells.is_empty() or cells[0].strip_edges() == ""):
			continue
		rows.append({"line": row_line, "cells": cells})
	f.close()
	return {"header": header, "rows": rows}


## Parses every CSV of `dir` in load order. Result:
##   files   PackedStringArray  load order
##   locales PackedStringArray  every locale column seen
##   rows    {key: {file, line, text: {locale: text}}}   effective after overrides (later file wins, per locale)
##   defs    [{key, file, line, text}]                    every valid definition in load order
##   issues  [{cat, sev, file, line, key, msg}]           sev "error" | "legacy" (da.csv) | "warning"
## `with_lint` adds the checks the loader itself never needs: keep-imports, generated .translation files, format placeholders,
## key ownership (tools/loc/key_owners.json below `repo_root`) and the voiced-key rule for zz_final.csv.
static func parse_dir(dir: String = LOC_DIR, repo_root: String = "res://", with_lint: bool = false) -> Dictionary:
	var issues: Array[Dictionary] = []
	var files := list_csv_files(dir)
	var defs: Array[Dictionary] = []
	var rows: Dictionary = {}
	var locales := PackedStringArray()
	var last_def: Dictionary = {}      # key -> {file, line} of the latest definition in a NON-legacy file
	var owners: Dictionary = load_owners(repo_root) if with_lint else {}
	for fname in files:
		var legacy := fname == LEGACY_FILE
		var is_final := fname == FINAL_FILE
		var sev := "legacy" if legacy else "error"
		var path := dir.path_join(fname)
		if with_lint:
			_check_keep_import(path, fname, sev, issues)
		var data := read_csv(path)
		if data.is_empty():
			issues.append(make_issue("unreadable", sev, fname, 0, "", "the file cannot be opened"))
			continue
		var header: PackedStringArray = data["header"]
		var cols: Array[String] = []
		for hi in range(1, header.size()):
			var col := header[hi].strip_edges().to_lower()
			cols.append(col)
			if col != "" and not (col in locales):
				locales.append(col)
		if header.is_empty() or header[0].strip_edges() != "keys" or not ("da" in cols) or not ("en" in cols):
			issues.append(make_issue("header", sev, fname, 1, "", "the header must be `keys,da,en` (got `%s`)" % ",".join(header)))
		var hcount := header.size()
		var seen_in_file: Dictionary = {}
		for r in (data["rows"] as Array):
			var cells: PackedStringArray = r["cells"]
			var line: int = r["line"]
			var key := cells[0].strip_edges() if cells.size() > 0 else ""
			if key == "" or key.begins_with(";") or key.begins_with("#"):
				continue
			if not is_valid_key(key):
				issues.append(make_issue("malformed", sev, fname, line, key.left(48), "key does not match ^[A-Z0-9_]+$ (row skipped)"))
				continue
			var ccount := cells.size()
			while ccount > hcount and cells[ccount - 1].strip_edges() == "":
				ccount -= 1
			if ccount != hcount:
				issues.append(make_issue("malformed", sev, fname, line, key, "expected %d columns, found %d (row skipped; quote texts that contain commas)" % [hcount, ccount]))
				continue
			# duplicates: da.csv is the legacy base and may be overridden silently; everything else has one definition
			if seen_in_file.has(key):
				issues.append(make_issue("duplicate", sev, fname, line, key, "defined twice in this file (first at line %d)" % int(seen_in_file[key])))
			elif not legacy and not is_final and last_def.has(key):
				var other: Dictionary = last_def[key]
				issues.append(make_issue("duplicate", "error", fname, line, key, "also defined in %s:%d (a key lives in exactly one non-legacy file)" % [other["file"], int(other["line"])]))
			seen_in_file[key] = line
			if not legacy:
				last_def[key] = {"file": fname, "line": line}
			var text: Dictionary = {}
			var missing: Array[String] = []
			for ci in cols.size():
				if cols[ci] == "":
					continue
				var raw := cells[ci + 1]
				if raw.strip_edges() == "":
					missing.append(cols[ci])
				else:
					text[cols[ci]] = unescape_text(raw)
			if "da" in missing or "en" in missing:
				issues.append(make_issue("missing-text", sev, fname, line, key, "no text for: %s" % ", ".join(missing)))
			defs.append({"key": key, "file": fname, "line": line, "text": text})
			if rows.has(key):
				var old: Dictionary = rows[key]
				for loc in text:
					(old["text"] as Dictionary)[loc] = text[loc]
				old["file"] = fname
				old["line"] = line
			else:
				rows[key] = {"file": fname, "line": line, "text": text.duplicate()}
	if with_lint:
		_check_junk(dir, issues)
		_lint_extra(files, defs, owners, repo_root, issues)
	return {"dir": dir, "files": files, "locales": locales, "rows": rows, "defs": defs, "issues": issues}


static func _check_keep_import(csv_path: String, fname: String, sev: String, issues: Array[Dictionary]) -> void:
	var imp := csv_path + ".import"
	if not FileAccess.file_exists(imp):
		issues.append(make_issue("keep-import", sev, fname, 0, "", "%s.import is missing (every CSV ships a committed keep-import: tools/loc/new_csv.py)" % fname))
		return
	var cfg := ConfigFile.new()
	var importer := ""
	if cfg.load(imp) == OK:
		importer = str(cfg.get_value("remap", "importer", ""))
	if importer != "keep":
		issues.append(make_issue("keep-import", sev, fname, 0, "", "%s.import has importer=\"%s\", it must be \"keep\" (otherwise --import writes .translation junk and exports drop the raw CSV)" % [fname, importer]))


static func _check_junk(dir: String, issues: Array[Dictionary]) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		return
	for f in da.get_files():
		if f.ends_with(".translation"):
			issues.append(make_issue("junk", "warning", f, 0, "", "generated .translation file (ignored by git; the runtime loader does not use it - delete it)"))


static func _lint_extra(files: PackedStringArray, defs: Array[Dictionary], owners: Dictionary, repo_root: String, issues: Array[Dictionary]) -> void:
	var voiced: Dictionary = voiced_keys(repo_root) if FINAL_FILE in files else {}
	for d in defs:
		var fname: String = d["file"]
		var legacy := fname == LEGACY_FILE
		var sev := "legacy" if legacy else "error"
		var key: String = d["key"]
		var text: Dictionary = d["text"]
		# da and en must take the same % arguments (a language switch must never raise a formatting error)
		if text.has("da") and text.has("en"):
			var sa := format_signature(text["da"])
			var sb := format_signature(text["en"])
			if sa != sb:
				issues.append(make_issue("format", sev, fname, int(d["line"]), key, "da takes [%s] but en takes [%s] (placeholder letters)" % [sa, sb]))
		if legacy:
			continue
		if fname == FINAL_FILE:
			if voiced.has(key):
				issues.append(make_issue("voiced", "error", fname, int(d["line"]), key, "voiced key (a dialogue line with a voice_key uses it): the copy pass may not change it (R.17)"))
			continue
		if owners.is_empty():
			continue
		var own := owner_of(key, owners)
		if own != "" and own != fname:
			issues.append(make_issue("ownership", "error", fname, int(d["line"]), key, "owned by %s (tools/loc/key_owners.json), defined in %s" % [own, fname]))
	if not owners.is_empty():
		var table: Dictionary = owners["files"]
		for fname in files:
			if fname != LEGACY_FILE and fname != FINAL_FILE and not table.has(fname):
				issues.append(make_issue("ownership", "warning", fname, 0, "", "%s is not listed in tools/loc/key_owners.json (add its key families)" % fname))
	elif not files.is_empty():
		issues.append(make_issue("ownership", "warning", "", 0, "", "%s was not found below %s: the ownership rule was not checked" % [OWNERS_PATH, repo_root]))


## {"files": {csv: {owner, prefix[], exact[], item_files[]}}, "item_keys": {csv: {KEY: true}}} - {} when the table is missing.
static func load_owners(repo_root: String) -> Dictionary:
	var path := repo_root.path_join(OWNERS_PATH)
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary) or not (data as Dictionary).has("files"):
		return {}
	var files: Dictionary = (data as Dictionary)["files"]
	var item_keys: Dictionary = {}
	for fname in files:
		var spec: Dictionary = files[fname]
		for lf in spec.get("item_files", []):
			var lp := repo_root.path_join(str(lf))
			if not FileAccess.file_exists(lp):
				continue
			var items: Variant = lua_parse(FileAccess.get_file_as_string(lp)).get("items", {})
			if not (items is Dictionary):
				continue
			if not item_keys.has(fname):
				item_keys[fname] = {}
			for id in (items as Dictionary):
				var base := "ITEM_" + str(id).to_upper()
				item_keys[fname][base] = true
				item_keys[fname][base + "_DESC"] = true
				item_keys[fname][base + "_HINT"] = true
	return {"files": files, "item_keys": item_keys}


## Key ownership (addendum 3.7): exact entry -> ITEM_<id>[_DESC|_HINT] of the item ids of a file's Lua item files ->
## the LONGEST matching prefix. "" when no file claims the key.
static func owner_of(key: String, owners: Dictionary) -> String:
	var files: Dictionary = owners.get("files", {})
	for fname in files:
		if key in (files[fname] as Dictionary).get("exact", []):
			return fname
	var item_keys: Dictionary = owners.get("item_keys", {})
	for fname in item_keys:
		if (item_keys[fname] as Dictionary).has(key):
			return fname
	var best := ""
	var best_len := -1
	for fname in files:
		for pf in (files[fname] as Dictionary).get("prefix", []):
			var p := str(pf)
			if key.begins_with(p) and p.length() > best_len:
				best = fname
				best_len = p.length()
	return best


## Keys of dialogue lines that carry a voice_key (their recorded/generated audio freezes the text): {KEY: "file"}.
static func voiced_keys(repo_root: String) -> Dictionary:
	var out: Dictionary = {}
	var da := DirAccess.open(repo_root.path_join("lua/dialogue"))
	if da == null:
		return out
	var block_rx := RegEx.new()
	block_rx.compile("\\{[^{}]*\\}")
	var text_rx := RegEx.new()
	text_rx.compile("text_key\\s*=\\s*\"([A-Z0-9_]+)\"")
	var voice_rx := RegEx.new()
	voice_rx.compile("voice_key\\s*=\\s*\"[^\"]+\"")
	for f in da.get_files():
		if not f.ends_with(".lua"):
			continue
		var src := FileAccess.get_file_as_string(repo_root.path_join("lua/dialogue").path_join(f))
		for b in block_rx.search_all(src):
			var block := b.get_string()
			if voice_rx.search(block) == null:
				continue
			var m := text_rx.search(block)
			if m != null:
				out[m.get_string(1)] = f
	return out


## Groups an issue list of parse_dir() into {files, key_count, errors, legacy, warnings} (strict: legacy -> errors).
static func summarize(report: Dictionary, strict: bool = false) -> Dictionary:
	var errors: Array[Dictionary] = []
	var legacy: Array[Dictionary] = []
	var warnings: Array[Dictionary] = []
	for iss in (report["issues"] as Array):
		match str(iss["sev"]):
			"error":
				errors.append(iss)
			"legacy":
				if strict:
					errors.append(iss)
				else:
					legacy.append(iss)
			_:
				warnings.append(iss)
	return {"files": report["files"], "key_count": (report["rows"] as Dictionary).size(), "errors": errors, "legacy": legacy, "warnings": warnings}


# ================================================================ static: tolerant reader for the Lua data subset

## Reads the DATA of a project Lua file: every top-level `name = <literal>` at column 0 (string, number, boolean or
## a table literal; tables become Dictionary (named entries) or Array (positional); functions and code are ignored).
## Used by the lint and by tests/loc_check.gd (item ids, quest objectives, config tables) - not a Lua interpreter.
static func lua_parse(text: String) -> Dictionary:
	var out: Dictionary = {}
	var rx := RegEx.new()
	rx.compile("(?m)^([A-Za-z_][A-Za-z0-9_]*)[ \\t]*=[ \\t]*")
	var from := 0
	for m in rx.search_all(text):
		var start := m.get_end()
		if start < from or start >= text.length():
			continue
		var lname := m.get_string(1)
		var c := text.unicode_at(start)
		var value: Variant = null
		if c == 123 or c == 34 or c == 39:
			var reader := _LuaReader.new(text, start)
			value = reader.value()
			from = reader.i
		else:
			var eol := text.find("\n", start)
			var raw := text.substr(start, (text.length() if eol < 0 else eol) - start)
			var cut := raw.find("--")
			if cut >= 0:
				raw = raw.substr(0, cut)
			value = _lua_scalar(raw.strip_edges())
			if value == null and raw.strip_edges() != "nil":
				continue
		if out.has(lname) and out[lname] is Dictionary and value is Dictionary:
			(out[lname] as Dictionary).merge(value as Dictionary, true)
		else:
			out[lname] = value
	return out


static func _lua_scalar(raw: String) -> Variant:
	if raw == "true":
		return true
	if raw == "false":
		return false
	if raw.is_valid_int():
		return raw.to_int()
	if raw.is_valid_float():
		return raw.to_float()
	return null


class _LuaReader:
	var s: String
	var i: int = 0
	var n: int = 0

	func _init(text: String, start: int = 0) -> void:
		s = text
		n = text.length()
		i = start

	func skip_ws() -> void:
		while i < n:
			var c := s.unicode_at(i)
			if c == 32 or c == 9 or c == 10 or c == 13:
				i += 1
			elif c == 45 and i + 1 < n and s.unicode_at(i + 1) == 45:
				if s.substr(i + 2, 2) == "[[":
					var e := s.find("]]", i + 4)
					i = n if e < 0 else e + 2
				else:
					var e2 := s.find("\n", i)
					i = n if e2 < 0 else e2 + 1
			else:
				return

	func string() -> String:
		var q := s.unicode_at(i)
		i += 1
		var start := i
		while i < n:
			var c := s.unicode_at(i)
			if c == 92 and i + 1 < n:
				i += 2
				continue
			if c == q:
				break
			i += 1
		var raw := s.substr(start, i - start)
		i += 1
		return raw.replace("\\\"", "\"").replace("\\'", "'")

	## One value. Tables -> Dictionary/Array, strings, numbers, true/false; nil and anything that is not data -> null.
	func value() -> Variant:
		skip_ws()
		if i >= n:
			return null
		var c := s.unicode_at(i)
		if c == 123:
			return table()
		if c == 34 or c == 39:
			return string()
		var start := i
		var depth := 0
		while i < n:
			var ch := s.unicode_at(i)
			if ch == 34 or ch == 39:
				string()
				continue
			if ch == 40 or ch == 91 or ch == 123:
				depth += 1
			elif ch == 41 or ch == 93 or ch == 125:
				if depth <= 0:
					break
				depth -= 1
			elif (ch == 44 or ch == 59) and depth <= 0:
				break
			elif ch == 45 and i + 1 < n and s.unicode_at(i + 1) == 45:
				break
			i += 1
		return _scalar(s.substr(start, i - start).strip_edges())

	static func _scalar(raw: String) -> Variant:
		if raw == "true":
			return true
		if raw == "false":
			return false
		if raw.is_valid_int():
			return raw.to_int()
		if raw.is_valid_float():
			return raw.to_float()
		return null

	func _is_ident_start(c: int) -> bool:
		return (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95

	func _is_ident(c: int) -> bool:
		return _is_ident_start(c) or (c >= 48 and c <= 57)

	func table() -> Variant:
		i += 1
		var named: Dictionary = {}
		var positional: Array = []
		while i < n:
			skip_ws()
			if i >= n:
				break
			var c := s.unicode_at(i)
			if c == 125:
				i += 1
				break
			if c == 44 or c == 59:
				i += 1
				continue
			var before := i
			var key: Variant = null
			var is_named := false
			if c == 91:
				var save := i
				i += 1
				var k: Variant = value()
				skip_ws()
				if i < n and s.unicode_at(i) == 93:
					i += 1
				skip_ws()
				if i < n and s.unicode_at(i) == 61 and (i + 1 >= n or s.unicode_at(i + 1) != 61):
					i += 1
					key = k
					is_named = true
				else:
					i = save + 1
			elif _is_ident_start(c):
				var j := i
				while j < n and _is_ident(s.unicode_at(j)):
					j += 1
				var k2 := j
				while k2 < n and (s.unicode_at(k2) == 32 or s.unicode_at(k2) == 9 or s.unicode_at(k2) == 10 or s.unicode_at(k2) == 13):
					k2 += 1
				if k2 < n and s.unicode_at(k2) == 61 and (k2 + 1 >= n or s.unicode_at(k2 + 1) != 61):
					key = s.substr(i, j - i)
					i = k2 + 1
					is_named = true
			var v: Variant = value()
			if is_named and key != null:
				named[key] = v
			else:
				positional.append(v)
			if i == before:
				i += 1
		if named.is_empty():
			return positional
		for pi in positional.size():
			if positional[pi] != null and not named.has(pi + 1):
				named[pi + 1] = positional[pi]
		return named
