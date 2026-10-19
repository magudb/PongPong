class_name ReleaseUpdates
extends Node
## One session-wide update check; no credentials, save migrations or executable replacement in-process.
signal changed
const Version := preload("res://scripts/release/release_version.gd")
const CACHE := "user://updates"
## A download has no total time limit (418 MB on a slow line takes long); it fails when no byte arrived for this long.
const STALL_SECONDS := 60.0
var state := "idle"
var available: Dictionary = {}
var downloaded_path := ""
var checked := false
var _request: HTTPRequest
var _downloading := false
var _last_bytes := 0
var _stalled := 0.0

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

## The automatic check at the title can be switched off in the update panel (settings.cfg [updates] auto_check, default on).
static func auto_check_enabled() -> bool:
	return SettingsStore.value("updates", "auto_check", true) != false

static func set_auto_check(on: bool) -> void:
	SettingsStore.store("updates", "auto_check", on, "update choice")

static func production() -> bool:
	return not OS.has_feature("editor") and DisplayServer.get_name() != "headless" and ProjectSettings.get_setting("release/channel", "development") == "stable"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_request = HTTPRequest.new()
	_request.use_threads = true
	_request.max_redirects = 5
	add_child(_request)
	_request.request_completed.connect(_completed)
	set_process(false)

func _process(delta: float) -> void:
	_watch(delta)

## The stall watchdog of a running download (it runs in the background: closing the update panel does not stop it).
func _watch(delta: float) -> void:
	if state != "downloading":
		set_process(false)
		return
	var bytes := downloaded_bytes()
	if bytes != _last_bytes:
		_last_bytes = bytes
		_stalled = 0.0
		return
	_stalled += delta
	if _stalled >= STALL_SECONDS:
		_request.cancel_request()
		_downloading = false
		if FileAccess.file_exists(downloaded_path): DirAccess.remove_absolute(downloaded_path)
		_set_state("download_failed")

func _set_state(value: String) -> void:
	state = value
	changed.emit()

func check(automatic := false) -> void:
	if not is_node_ready():
		check.call_deferred(automatic)
		return
	if state in ["checking", "downloading", "installing"]: return
	if automatic and (checked or not production() or not auto_check_enabled()): return
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
	if state not in ["available", "download_failed"] or available.is_empty(): return
	var path := ProjectSettings.globalize_path(CACHE.path_join(available.version))
	if DirAccess.make_dir_recursive_absolute(path) != OK:
		_set_state("download_failed")
		return
	downloaded_path = path.path_join(available.name)
	_request.timeout = 0
	_request.body_size_limit = 1073741824
	_request.download_file = downloaded_path
	_downloading = true
	_last_bytes = 0
	_stalled = 0.0
	_set_state("downloading")
	set_process(true)
	if _request.request(available.url, PackedStringArray(["User-Agent: Traetoppen/" + current_version()])) != OK:
		_downloading = false
		_set_state("download_failed")

func progress() -> float:
	return clampf(float(downloaded_bytes()) / maxf(1, float(download_size())), 0, 1)

func downloaded_bytes() -> int:
	return _request.get_downloaded_bytes() if _request != null else 0

func download_size() -> int:
	return int(available.get("size", 0))

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
		_set_state("install_failed")
		return false
	if not FileAccess.file_exists(downloaded_path) or FileAccess.get_sha256(downloaded_path) != available.get("sha256", ""):
		_set_state("download_failed")
		return false
	var parent := install_target().get_base_dir()
	var probe := parent.path_join(".Traetoppen-write-" + str(OS.get_process_id()))
	if DirAccess.make_dir_absolute(probe) != OK:
		_set_state("install_failed")
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
		_set_state("install_failed")
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
		_set_state("install_failed")
		return false
	_set_state("installing")
	# Allow large packages to finish validation and extraction before the game exits.
	for attempt in 1200:
		if FileAccess.file_exists(ready): break
		if not OS.is_process_running(process): break
		await get_tree().create_timer(0.1, true).timeout
	if not FileAccess.file_exists(ready) or FileAccess.get_file_as_string(ready) != "ready":
		if OS.is_process_running(process): OS.kill(process)
		_set_state("install_failed")
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
