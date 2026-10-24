extends Node
## Pooled audio playback for SFX, music, and Danish voice lines.

const SFX_POOL_SIZE := 8
const VOICE_DIR := "res://assets/audio/voice"
const SFX_DIR := "res://assets/audio/sfx"
const MUSIC_DIR := "res://assets/audio/music"
const AMBIENT_DIR := "res://assets/audio/amb"
const SETTINGS_PATH := SettingsStore.PATH
## The buses whose volume settings.cfg [audio] keeps (keys: the lower-case bus name). SettingsUI shows four of them.
const VOLUME_BUSES: Array[String] = ["Master","SFX","Music","Voice","Ambient"]
const DEFAULT_VOLUME := 0.8
## Fades never change a PLAYING player's volume_db. Setting it makes AudioServer swap the playback's bus details, and Godot 4.7.2
## frees the old copy at the end of the next frame while the mixer thread may still be copying it (AudioServer::_mix_step): a
## use-after-free that crashed a headless gate run in the audio thread (an uncapped headless frame lasts well under a millisecond,
## and a tween swapped every frame). Every fade moves the volume of a fader bus instead, a plain float the mixer reads; a player's
## own volume_db is only set while it is stopped (assigning `stream` stops it first).
const MUSIC_FADER := "MusicFade"
const AMBIENT_FADERS: Array[String] = ["AmbientFadeA","AmbientFadeB"]
## The music fades from and to this level (absolute dB, as the player's volume plus its fader).
const MUSIC_FADE_FLOOR_DB := -40.0
const SHUTDOWN_TIMEOUT_MS := 2000
## An ambient loop plays at this volume; its fader adds the duck (0 at full level) or AMBIENT_SILENT_DB - AMBIENT_LEVEL_DB.
const AMBIENT_LEVEL_DB := -16.0
const AMBIENT_SILENT_DB := -60.0

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_rr: int = 0                    # round-robin cursor: the slot stolen next when the pool is full (the "oldest" in FIFO order)
var _music_player: AudioStreamPlayer
var _music_tween: Tween
var _music_request: int = 0
var _voice_player: AudioStreamPlayer
var _ambient_players: Array[AudioStreamPlayer] = []
var _ambient_tweens: Array[Tween] = []
var _ambient_id := ""
var _ambient_slot := 0
var _ambient_duck := 0.0
var _rain_player: AudioStreamPlayer
var _music_fader := MUSIC_FADER         # fader bus names: the autoload owns the shared ones, any other instance (a test probe) its own
var _ambient_faders: Array[String] = []
var _own_faders := false                # true when this instance created per-instance faders and removes them on exit
var _rain_id := ""
var _cues: Array[Dictionary] = []
var _shutting_down := false
## Weak references include replaced/stopped streams still retiring on the mixer thread.
var _playbacks: Array[WeakRef] = []
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

	_setup_buses()
	_music_fader = _add_fader(MUSIC_FADER,"Music")
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = _music_fader
	_music_player.volume_db = music_volume_db
	add_child(_music_player)

	_voice_player = AudioStreamPlayer.new()
	_voice_player.bus = "Voice"
	add_child(_voice_player)

	for index in 2:
		var fader := _add_fader(AMBIENT_FADERS[index],"Ambient")
		_set_fader_db(AMBIENT_SILENT_DB-AMBIENT_LEVEL_DB,fader)
		_ambient_faders.append(fader)
		var ambient := AudioStreamPlayer.new()
		ambient.bus = fader
		ambient.volume_db = AMBIENT_LEVEL_DB
		add_child(ambient)
		_ambient_players.append(ambient)
		_ambient_tweens.append(null)
	_rain_player = AudioStreamPlayer.new()
	_rain_player.bus = "Ambient"
	_rain_player.volume_db = -22
	add_child(_rain_player)
	apply_saved_volumes()
	LocalizationManager.locale_changed.connect(func(_locale):stop_voice())
	var director: Node = load("res://scripts/audio/audio_director.gd").new()
	director.name = "AudioDirector"
	add_child.call_deferred(director)


func _setup_buses() -> void:
	for bus_name in ["SFX", "Music", "Voice", "Ambient"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.get_bus_count()
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")

## A fader bus that sends to `send`. The autoload uses the shared name; another instance (codex_review's probe) gets its own bus,
## so its fades never move the game's music, and removes it again on exit.
func _add_fader(base: String,send: String) -> String:
	var shared := is_inside_tree() and get_parent() == get_tree().root and name == &"AudioManager"
	var bus := base if shared else "%s_%d" % [base,get_instance_id()]
	_own_faders = _own_faders or not shared
	var index := AudioServer.get_bus_index(bus)
	if index == -1:
		index = AudioServer.get_bus_count()
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index,bus)
	AudioServer.set_bus_send(index,send)
	return bus

func _fader_db(bus: String) -> float:
	var index := AudioServer.get_bus_index(bus)
	return AudioServer.get_bus_volume_db(index) if index>=0 else 0.0

## Tween target (tween_method passes the value first, the bound bus name second).
func _set_fader_db(db: float,bus: String) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index>=0:AudioServer.set_bus_volume_db(index,db)

func _fade_music(target_db: float,seconds: float) -> Tween:
	var tween := create_tween()
	tween.tween_method(_set_fader_db.bind(_music_fader),_fader_db(_music_fader),target_db-music_volume_db,seconds)
	return tween


func _play(player: AudioStreamPlayer) -> void:
	player.play()
	_playbacks = _playbacks.filter(func(reference: WeakRef) -> bool: return reference.get_ref() != null)
	if player.has_stream_playback():
		_playbacks.append(weakref(player.get_stream_playback()))


func play_sfx(sfx_id: String, volume_db: float = NAN, pitch: float = 1.0) -> void:
	sfx_id = sfx_id.trim_prefix("sfx/")
	if _shutting_down:
		_record("sfx",sfx_id,false)
		return
	var stream := _load_stream(SFX_DIR, sfx_id)
	_record("sfx",sfx_id,stream!=null)
	if stream == null:
		return
	for p in _sfx_pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = sfx_volume_db if is_nan(volume_db) else volume_db
			p.pitch_scale = pitch
			_play(p)
			return
	# Steal the slot the pool used longest ago (FIFO over SFX_POOL_SIZE, not always slot 0)
	var stolen := _sfx_pool[_sfx_rr]
	_sfx_rr = (_sfx_rr + 1) % _sfx_pool.size()
	stolen.stream = stream
	stolen.volume_db = sfx_volume_db if is_nan(volume_db) else volume_db
	stolen.pitch_scale = pitch
	_play(stolen)


func play_music(track_id: String, fade_seconds: float = 1.0) -> void:
	track_id = track_id.trim_prefix("music/")
	if _shutting_down:
		_record("music",track_id,false)
		return
	var stream := _load_stream(MUSIC_DIR, track_id)
	_record("music",track_id,stream!=null)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:stream.loop = true
	_cancel_music_transition()
	var request := _music_request
	if _music_player.playing and _music_player.stream == stream:
		_set_fader_db(0.0,_music_fader)
		return
	if _music_player.playing and fade_seconds > 0:
		_music_tween = _fade_music(MUSIC_FADE_FLOOR_DB, fade_seconds * 0.5)
		_music_tween.tween_callback(_start_music.bind(stream, fade_seconds, request))
	else:
		_start_music(stream, fade_seconds, request)


func _start_music(stream: AudioStream, fade_seconds: float, request: int) -> void:
	if request != _music_request:
		return
	_music_player.stream = stream    # stops the old playback: the volume below is set on a stopped player
	_music_player.volume_db = music_volume_db
	_set_fader_db(MUSIC_FADE_FLOOR_DB-music_volume_db if fade_seconds > 0.0 else 0.0,_music_fader)
	_play(_music_player)
	if fade_seconds > 0:
		_music_tween = _fade_music(music_volume_db, fade_seconds)


func stop_music(fade_seconds: float = 1.0) -> void:
	_cancel_music_transition()
	var request := _music_request
	if not _music_player.playing:
		return
	if fade_seconds <= 0:
		_music_player.stop()
		return
	_music_tween = _fade_music(MUSIC_FADE_FLOOR_DB, fade_seconds)
	_music_tween.tween_callback(func() -> void:
		if request == _music_request:
			_music_player.stop())


func _cancel_music_transition() -> void:
	_music_request += 1
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = null


func play_voice(voice_key: String, volume_db: float = NAN) -> void:
	stop_voice()
	if _shutting_down or not LocalizationManager.is_da():
		_record("voice",voice_key,false)
		return
	var stream := _load_stream("", voice_key)
	if stream == null:
		# Try full path under voice dir
		stream = _load_stream(VOICE_DIR, voice_key.get_file())
	_record("voice",voice_key,stream!=null)
	if stream == null:
		return
	_voice_player.stream = stream
	_voice_player.volume_db = voice_volume_db if is_nan(volume_db) else volume_db
	_play(_voice_player)


## True when a voice line with this key exists (the same lookup play_voice does, without loading the stream).
func voice_exists(voice_key: String) -> bool:
	return _find_stream("", voice_key) != "" or _find_stream(VOICE_DIR, voice_key.get_file()) != ""


func is_voice_playing() -> bool:
	return _voice_player.playing


func stop_voice() -> void:
	_voice_player.stop()


func set_master_volume(db: float) -> void:
	master_volume_db = db
	set_bus_volume("Master",db_to_linear(db))

func cue_log() -> Array[Dictionary]:
	return _cues.duplicate(true)

func clear_cue_log() -> void:
	_cues.clear()

func _record(kind: String,id: String,played: bool) -> void:
	_cues.append({"t_msec":Time.get_ticks_msec(),"kind":kind,"id":id,"played":played})
	if _cues.size()>256:_cues.pop_front()

func apply_saved_volumes() -> void:
	var config := SettingsStore.read()
	for bus in VOLUME_BUSES:
		_apply_bus(bus,saved_volume(config,bus))

## The saved linear volume of a bus (0..1); a missing or garbage value is DEFAULT_VOLUME.
static func saved_volume(config: ConfigFile,bus: String) -> float:
	var value: Variant = config.get_value("audio",bus.to_lower(),DEFAULT_VOLUME)
	return clampf(float(value),0,1) if value is float or value is int else DEFAULT_VOLUME

func _apply_bus(bus: String,linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index<0:return
	AudioServer.set_bus_mute(index,linear<=0)
	AudioServer.set_bus_volume_db(index,linear_to_db(maxf(linear,0.0001)))

## Applies a volume and, with `persist`, saves it. SettingsUI applies every slider step live and saves once the slider rests.
func set_bus_volume(bus: String,linear: float,persist := true) -> void:
	if bus not in VOLUME_BUSES:return
	linear = clampf(linear,0,1)
	_apply_bus(bus,linear)
	if persist:SettingsStore.store("audio",bus.to_lower(),linear,"volume")

func _fade_ambient(index: int,target: float,seconds: float,stop := false) -> void:
	var player := _ambient_players[index]
	var fader := _ambient_faders[index]
	if _ambient_tweens[index]!=null and _ambient_tweens[index].is_valid():_ambient_tweens[index].kill()
	if seconds<=0:
		_set_fader_db(target-AMBIENT_LEVEL_DB,fader)
		if stop:player.stop()
		return
	var tween := create_tween()
	_ambient_tweens[index] = tween
	tween.tween_method(_set_fader_db.bind(fader),_fader_db(fader),target-AMBIENT_LEVEL_DB,seconds)
	if stop:tween.tween_callback(player.stop)

func play_ambience(id: String,fade_seconds := 1.5) -> void:
	id = id.trim_prefix("amb/")
	if _shutting_down:
		_record("amb",id,false)
		return
	var stream := _load_stream(AMBIENT_DIR,id) if id!="" else null
	_record("amb",id,stream!=null)
	if id==_ambient_id:return
	if stream==null and id!="":return
	_fade_ambient(_ambient_slot,AMBIENT_SILENT_DB,fade_seconds,true)
	_ambient_id = id
	if stream==null:return
	_ambient_slot = 1-_ambient_slot
	var player := _ambient_players[_ambient_slot]
	if stream is AudioStreamOggVorbis:stream.loop = true
	player.stream = stream
	_fade_ambient(_ambient_slot,AMBIENT_SILENT_DB,0.0)
	_play(player)
	_fade_ambient(_ambient_slot,AMBIENT_LEVEL_DB+_ambient_duck,fade_seconds)

func duck_ambience(db: float) -> void:
	var next := clampf(db,-24,0)
	if next==_ambient_duck:return
	_ambient_duck = next
	if _ambient_id!="":_fade_ambient(_ambient_slot,AMBIENT_LEVEL_DB+_ambient_duck,0.5)

func play_rain(on: bool) -> void:
	if _shutting_down:
		_record("amb","rain" if on else "",false)
		return
	var id := "rain" if on else ""
	if id==_rain_id:return
	_rain_id = id
	var stream := _load_stream(AMBIENT_DIR,id) if on else null
	_record("amb",id,stream!=null)
	if stream==null:
		_rain_player.stop()
		return
	if stream is AudioStreamOggVorbis:stream.loop = true
	_rain_player.stream = stream
	_play(_rain_player)

func stop_world_audio() -> void:
	play_ambience("",0.3)
	play_rain(false)
	stop_music(0.3)
	stop_voice()
	for player in _sfx_pool:player.stop()

func _silence_all() -> void:
	_cancel_music_transition()
	for tween in _ambient_tweens:
		if tween!=null and tween.is_valid():tween.kill()
	for player in _sfx_pool+_ambient_players+[_music_player,_voice_player,_rain_player]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null

func prepare_shutdown() -> void:
	_shutting_down = true
	_silence_all()
	# stop() queues a fade and deletion on the mixer thread; the main thread then
	# retires the playback. A fixed delay races that handoff on a loaded runner.
	var deadline := Time.get_ticks_msec()+SHUTDOWN_TIMEOUT_MS
	while not _playbacks.is_empty():
		_playbacks = _playbacks.filter(func(reference: WeakRef) -> bool: return reference.get_ref() != null)
		if _playbacks.is_empty() or Time.get_ticks_msec()>=deadline:
			break
		await get_tree().process_frame
	_playbacks.clear()

func _exit_tree() -> void:
	_shutting_down = true
	_silence_all()
	if _own_faders:
		for bus in [_music_fader]+_ambient_faders:
			var index := AudioServer.get_bus_index(bus)
			if index>=0:AudioServer.remove_bus(index)


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
