class_name ReleaseUpdates
extends Node
## One session-wide update check; no credentials, save migrations or executable replacement in-process.
signal changed
const Version := preload("res://scripts/release/release_version.gd")
const CACHE := "user://updates"
## Reason codes the install helpers write into their result file, and the message each one shows.
const FAILURES := {"folder": "UPDATE_FAIL_FOLDER", "checksum": "UPDATE_FAIL_CHECKSUM", "package": "UPDATE_FAIL_PACKAGE", "game_running": "UPDATE_FAIL_GAME_RUNNING", "locked": "UPDATE_FAIL_LOCKED", "launch": "UPDATE_FAIL_LAUNCH"}
var state := "idle"
var available: Dictionary = {}
var failure := ""
## Outcome of the install a previous session handed to its helper: {} or {"status": "installed"|"failed", "reason": code}.
var report: Dictionary = {}
var downloaded_path := ""
var checked := false
var _request: HTTPRequest
var _downloading := false

static func inst() -> ReleaseUpdates:
	var tree := Engine.get_main_loop() as SceneTree
	var found := tree.root.get_node_or_null("ReleaseUpdates") as ReleaseUpdates
	if found != null: return found
	var pending := tree.root.get_meta("tt_release_updates") as ReleaseUpdates if tree.root.has_meta("tt_release_updates") else null
	if is_instance_valid(pending): return pending
	var service := ReleaseUpdates.new()
	service.name = "ReleaseUpdates"
	tree.root.set_meta("tt_release_updates", service)
	tree.root.add_child.call_deferred(service)
	return service

static func current_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))

static func repository() -> String:
	return str(ProjectSettings.get_setting("release/repository", "magudb/PongPong"))

static func platform_name() -> String:
	return "windows" if OS.get_name() == "Windows" else "macos" if OS.get_name() == "macOS" else ""

static func production() -> bool:
	return not OS.has_feature("editor") and DisplayServer.get_name() != "headless" and ProjectSettings.get_setting("release/channel", "development") == "stable"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_request = HTTPRequest.new()
	_request.use_threads = true
	_request.max_redirects = 5
	add_child(_request)
	_request.request_completed.connect(_completed)
	report = take_report()
	prune_downloads()

func _set_state(value: String) -> void:
	state = value
	changed.emit()

func _fail(reason: String) -> void:
	failure = reason if FAILURES.has(reason) else ""
	# The helper found the archive itself unusable: a retry has to download it again.
	if failure in ["checksum", "package"] and FileAccess.file_exists(downloaded_path): DirAccess.remove_absolute(downloaded_path)
	_set_state("install_failed")

## Update archives are about 400 MB each and sit next to the saves. Keep at most one: the download being made (`keep`),
## or else one of a release newer than this build, which a failed install can retry; an installed one is removed.
func prune_downloads(keep := "") -> void:
	var folder := ProjectSettings.globalize_path(CACHE)
	if not DirAccess.dir_exists_absolute(folder): return
	for version in DirAccess.get_directories_at(folder):
		if version == keep or keep.is_empty() and Version.newer(version, current_version()): continue
		var path := folder.path_join(version)
		for file in DirAccess.get_files_at(path): DirAccess.remove_absolute(path.path_join(file))
		DirAccess.remove_absolute(path)

## The message for the current install failure, or for the one reported from the previous session.
static func failure_key(reason: String) -> String:
	return FAILURES.get(reason, "UPDATE_STATE_INSTALL_FAILED")

## A helper result file: {"status": "installed"|"rolled_back"|"failed", "reason": known code or ""}, or {} when unreadable.
static func read_result(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var json := JSON.new()
	# Windows PowerShell writes UTF-8 with a byte order mark.
	if json.parse(FileAccess.get_file_as_string(path).trim_prefix("\ufeff")) != OK or not json.data is Dictionary: return {}
	var status := str(json.data.get("status", ""))
	if status not in ["installed", "rolled_back", "failed"]: return {}
	var reason := str(json.data.get("reason", ""))
	return {"status": status, "reason": reason if FAILURES.has(reason) else ""}

## Reads and removes the result files install helpers left behind; the newest one is the outcome to tell the player.
func take_report() -> Dictionary:
	var folder := ProjectSettings.globalize_path(CACHE)
	if not DirAccess.dir_exists_absolute(folder): return {}
	var newest := ""
	for file in DirAccess.get_files_at(folder):
		if not file.begins_with("install-"): continue
		var path := folder.path_join(file)
		if file.get_extension() == "json" and (newest.is_empty() or FileAccess.get_modified_time(path) >= FileAccess.get_modified_time(newest)): newest = path
	var outcome := read_result(newest) if not newest.is_empty() else {}
	for file in DirAccess.get_files_at(folder):
		if file.begins_with("install-") and file.get_extension() in ["json", "ready"]: DirAccess.remove_absolute(folder.path_join(file))
	if outcome.is_empty(): return {}
	return {"status": "installed", "reason": ""} if outcome.status == "installed" else {"status": "failed", "reason": outcome.reason}

func acknowledge_report() -> void:
	if report.is_empty(): return
	report.clear()
	changed.emit()

func check(automatic := false) -> void:
	if not is_node_ready():
		check.call_deferred(automatic)
		return
	if state in ["checking", "downloading", "installing"]: return
	if automatic and (checked or not production()): return
	if platform_name().is_empty():
		_set_state("unsupported")
		return
	checked = true
	available.clear()
	_downloading = false
	_request.timeout = 15
	_request.body_size_limit = 1048576
	_request.download_file = ""
	_set_state("checking")
	var headers := PackedStringArray(["Accept: application/vnd.github+json", "X-GitHub-Api-Version: 2022-11-28", "User-Agent: Traetoppen/" + current_version()])
	if _request.request("https://api.github.com/repos/%s/releases/latest" % repository(), headers) != OK:
		_set_state("unavailable")

func accept_release(payload: Dictionary) -> void:
	available = Version.select_asset(payload, current_version(), repository(), platform_name())
	_set_state("available" if not available.is_empty() else "current")

func _completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _downloading:
		_downloading = false
		if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not FileAccess.file_exists(downloaded_path) or FileAccess.get_sha256(downloaded_path) != available.get("sha256", ""):
			if FileAccess.file_exists(downloaded_path): DirAccess.remove_absolute(downloaded_path)
			_set_state("download_failed")
			return
		_set_state("ready")
		return
	if result == HTTPRequest.RESULT_SUCCESS and code == 404:
		_set_state("current")
		return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_set_state("unavailable")
		return
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or not json.data is Dictionary:
		_set_state("unavailable")
		return
	accept_release(json.data)

func download() -> void:
	if state not in ["available", "download_failed", "install_failed"] or available.is_empty(): return
	prune_downloads(available.version)
	var path := ProjectSettings.globalize_path(CACHE.path_join(available.version))
	if DirAccess.make_dir_recursive_absolute(path) != OK:
		_set_state("download_failed")
		return
	downloaded_path = path.path_join(available.name)
	# A verified download outlives a failed install, so trying again does not fetch it twice.
	if FileAccess.file_exists(downloaded_path) and FileAccess.get_sha256(downloaded_path) == available.get("sha256", ""):
		_set_state("ready")
		return
	_request.timeout = 1800
	_request.body_size_limit = 1073741824
	_request.download_file = downloaded_path
	_downloading = true
	_set_state("downloading")
	if _request.request(available.url, PackedStringArray(["User-Agent: Traetoppen/" + current_version()])) != OK:
		_downloading = false
		_set_state("download_failed")

func progress() -> float:
	return clampf(float(_request.get_downloaded_bytes()) / maxf(1, float(available.get("size", 1))), 0, 1)

func install_target() -> String:
	var executable := OS.get_executable_path()
	if platform_name() == "macos":
		var folder := executable.get_base_dir()
		return folder.trim_suffix("/Contents/MacOS") if folder.ends_with("/Traetoppen.app/Contents/MacOS") else ""
	if platform_name() == "windows" and executable.get_file() == "Traetoppen.exe" and executable.get_base_dir().get_file() == "Traetoppen":
		return executable.get_base_dir()
	return ""

func install() -> bool:
	if state != "ready" or install_target().is_empty():
		_fail("folder")
		return false
	if not FileAccess.file_exists(downloaded_path) or FileAccess.get_sha256(downloaded_path) != available.get("sha256", ""):
		_set_state("download_failed")
		return false
	var parent := install_target().get_base_dir()
	var probe := parent.path_join(".Traetoppen-write-" + str(OS.get_process_id()))
	if DirAccess.make_dir_absolute(probe) != OK:
		_fail("folder")
		return false
	DirAccess.remove_absolute(probe)
	var world := get_tree().get_first_node_in_group("world_2d")
	if world != null and not SaveManager.autosave():
		_set_state("save_failed")
		return false
	var extension := "ps1" if platform_name() == "windows" else "sh"
	var helper := ProjectSettings.globalize_path(CACHE.path_join("install." + extension))
	var file := FileAccess.open(helper, FileAccess.WRITE)
	if file == null:
		_fail("")
		return false
	file.store_string(FileAccess.get_file_as_string("res://scripts/release/install_windows.ps1" if extension == "ps1" else "res://scripts/release/install_macos.sh"))
	file.close()
	var result := ProjectSettings.globalize_path(CACHE.path_join("install-" + str(OS.get_process_id()) + ".json"))
	var ready := result + ".ready"
	if FileAccess.file_exists(ready): DirAccess.remove_absolute(ready)
	var args := PackedStringArray([helper, str(OS.get_process_id()), downloaded_path, install_target(), available.sha256, result])
	var command := "/bin/bash"
	if extension == "ps1":
		command = OS.get_environment("SystemRoot").path_join("System32/WindowsPowerShell/v1.0/powershell.exe")
		args = PackedStringArray(["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", helper, "-ParentProcessId", str(OS.get_process_id()), "-Archive", downloaded_path, "-Target", install_target(), "-ExpectedSha", available.sha256, "-Result", result])
	var process := OS.create_process(command, args)
	if process < 0:
		_fail("")
		return false
	_set_state("installing")
	# Allow large packages to finish validation and extraction before the game exits.
	for attempt in 1200:
		if FileAccess.file_exists(ready): break
		if not OS.is_process_running(process): break
		await get_tree().create_timer(0.1, true).timeout
	if not FileAccess.file_exists(ready) or FileAccess.get_file_as_string(ready).trim_prefix("\ufeff") != "ready":
		if OS.is_process_running(process): OS.kill(process)
		# The helper names why it refused; the game is still running, so this session reports it.
		var outcome := read_result(result)
		if FileAccess.file_exists(result): DirAccess.remove_absolute(result)
		_fail(outcome.get("reason", ""))
		return false
	DirAccess.remove_absolute(ready)
	GameManager.quit_game()
	return true

func cancel_download() -> void:
	if state != "downloading": return
	_request.cancel_request()
	_downloading = false
	if FileAccess.file_exists(downloaded_path): DirAccess.remove_absolute(downloaded_path)
	_set_state("available")
