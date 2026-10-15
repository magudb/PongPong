extends Node
## Pooled audio playback for SFX, music, and Danish voice lines.

const SFX_POOL_SIZE := 8
const VOICE_DIR := "res://assets/audio/voice"
const SFX_DIR := "res://assets/audio/sfx"
const MUSIC_DIR := "res://assets/audio/music"

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_rr: int = 0                    # round-robin cursor: the slot stolen next when the pool is full (the "oldest" in FIFO order)
var _music_player: AudioStreamPlayer
var _voice_player: AudioStreamPlayer
var _ambient_players: Array[AudioStreamPlayer3D] = []
var _stream_paths: Dictionary = {}      # "dir|id" -> resolved path ("" = does not exist): ResourceLoader.exists is hit once per id

var master_volume_db: float = 0.0
var sfx_volume_db: float = -4.0
var music_volume_db: float = -8.0
var voice_volume_db: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)

	_voice_player = AudioStreamPlayer.new()
	_voice_player.bus = "Voice"
	add_child(_voice_player)

	_setup_buses()


func _setup_buses() -> void:
	for bus_name in ["SFX", "Music", "Voice", "Ambient"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.get_bus_count()
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func play_sfx(sfx_id: String, volume_db: float = NAN, pitch: float = 1.0) -> void:
	var stream := _load_stream(SFX_DIR, sfx_id)
	if stream == null:
		return
	for p in _sfx_pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = sfx_volume_db if is_nan(volume_db) else volume_db
			p.pitch_scale = pitch
			p.play()
			return
	# Steal the slot the pool used longest ago (FIFO over SFX_POOL_SIZE, not always slot 0)
	var stolen := _sfx_pool[_sfx_rr]
	_sfx_rr = (_sfx_rr + 1) % _sfx_pool.size()
	stolen.stream = stream
	stolen.volume_db = sfx_volume_db if is_nan(volume_db) else volume_db
	stolen.pitch_scale = pitch
	stolen.play()


func play_music(track_id: String, fade_seconds: float = 1.0) -> void:
	var stream := _load_stream(MUSIC_DIR, track_id)
	if stream == null:
		return
	if _music_player.playing and _music_player.stream == stream:
		return
	if _music_player.playing and fade_seconds > 0:
		var tween := create_tween()
		tween.tween_property(_music_player, "volume_db", -40.0, fade_seconds * 0.5)
		await tween.finished
	_music_player.stream = stream
	_music_player.volume_db = -40.0 if fade_seconds > 0.0 else music_volume_db
	_music_player.play()
	if fade_seconds > 0:
		var tween2 := create_tween()
		tween2.tween_property(_music_player, "volume_db", music_volume_db, fade_seconds)


func stop_music(fade_seconds: float = 1.0) -> void:
	if not _music_player.playing:
		return
	if fade_seconds <= 0:
		_music_player.stop()
		return
	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", -40.0, fade_seconds)
	tween.tween_callback(_music_player.stop)


func play_voice(voice_key: String, volume_db: float = NAN) -> void:
	var stream := _load_stream("", voice_key)
	if stream == null:
		# Try full path under voice dir
		stream = _load_stream(VOICE_DIR, voice_key.get_file())
	if stream == null:
		return
	_voice_player.stream = stream
	_voice_player.volume_db = voice_volume_db if is_nan(volume_db) else volume_db
	_voice_player.play()


## True when a voice line with this key exists (the same lookup play_voice does, without loading the stream).
func voice_exists(voice_key: String) -> bool:
	return _find_stream("", voice_key) != "" or _find_stream(VOICE_DIR, voice_key.get_file()) != ""


func is_voice_playing() -> bool:
	return _voice_player.playing


func stop_voice() -> void:
	_voice_player.stop()


func set_master_volume(db: float) -> void:
	master_volume_db = db
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)


func _find_stream(base_dir: String, id: String) -> String:
	var key := base_dir + "|" + id
	if _stream_paths.has(key):
		return _stream_paths[key]
	var candidates: Array[String] = []
	if base_dir != "":
		candidates.append(base_dir.path_join(id + ".ogg"))
		candidates.append(base_dir.path_join(id + ".wav"))
		candidates.append(base_dir.path_join(id + ".mp3"))
	candidates.append(id + ".ogg")
	candidates.append(id + ".wav")
	candidates.append("res://assets/audio/" + id + ".ogg")

	for path in candidates:
		if ResourceLoader.exists(path):
			_stream_paths[key] = path
			return path
	_stream_paths[key] = ""
	return ""


func _load_stream(base_dir: String, id: String) -> AudioStream:
	var path := _find_stream(base_dir, id)
	return load(path) as AudioStream if path != "" else null
