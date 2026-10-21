extends RefCounted
const SECTION := "voice"
const TIMEOUT_S := 120.0
func run(t) -> void:
	var result: Dictionary = t.run_tool(t.python(), ["-B",ProjectSettings.globalize_path("res://tools/voice/generate_voice.py"),"--check"])
	t.check("manifest_in_sync",result.code==0,str(result.output))
	var index: Dictionary = t.run_tool(t.python(), ["-B",ProjectSettings.globalize_path("res://tools/voice/build_index.py"),"--check"])
	t.check("index_matches_csv",index.code==0,str(index.output))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/voice/manifest.json"))
	var real := 0
	var generated := 0
	var deferred := 0
	for key in manifest.lines:
		var row: Dictionary = manifest.lines[key]
		if row.kind=="missing":
			deferred += 1
			t.check("draft_voice_explicit_"+str(key),str(row.reason)=="draft social copy; bake after copy review" and manifest.missing.has(key))
		else:
			if row.kind=="recorded":real += 1
			else:generated += 1
			t.check("stream_"+str(key),AudioManager.voice_exists(str(key)) and ResourceLoader.exists("res://assets/audio/"+str(key)+".ogg"))
	t.check("eleven_human_recordings",real==11)
	t.check("complete_voice_manifest",real+generated+deferred==manifest.lines.size() and generated>=175)
	var mapping: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/voice/_user_recordings_v0/mapping.json"))
	t.check("fourteen_originals_byte_identical",mapping.size()==14 and mapping.all(func(row):return FileAccess.get_sha256("res://"+str(row.source))==str(row.sha256) and FileAccess.get_sha256("res://assets/audio/voice/_user_recordings_v0/"+str(row.source).get_file())==str(row.sha256)))
	AudioManager.clear_cue_log()
	AudioManager.play_voice("voice/unknown/missing")
	t.check("missing_silent_and_logged",not AudioManager.is_voice_playing() and AudioManager.cue_log().back().played==false)
	LocalizationManager.set_locale("en",false)
	AudioManager.play_voice("voice/mayor_lyra/greet_2")
	t.check("english_does_not_play_danish",not AudioManager.is_voice_playing() and not AudioManager.cue_log().back().played)
	LocalizationManager.set_locale("da",false)
	AudioManager.play_voice("voice/mayor_lyra/greet_2")
	t.check("recorded_line_plays",AudioManager.is_voice_playing() and AudioManager.cue_log().back().played)
	LocalizationManager.set_locale("en",false)
	t.check("locale_switch_stops_voice",not AudioManager.is_voice_playing())
	LocalizationManager.set_locale("da",false)
	await t.start_world()
	var screen: Control = t.world().game_ui.get_screen(&"dialogue_ui")
	var text_key := str(manifest.lines["voice/mayor_lyra/greet_2"].text_key)
	var show := func() -> void:await screen.show_lines({"id":"mayor_lyra","name_key":"NPC_MAYOR_LYRA"},[{"text_key":text_key,"voice_key":"voice/mayor_lyra/greet_2"}])
	show.call()
	await t.frames(3)
	t.check("dialogue_voice_indicator",screen.is_open() and screen.get_node("%VoiceGroup").visible and AudioManager.is_voice_playing())
	t.tap_key(KEY_ESCAPE)
	await t.frames(3)
	t.check("dialogue_close_stops_voice",not screen.is_open() and not AudioManager.is_voice_playing())
	var config := ConfigFile.new()
	config.load(AudioManager.SETTINGS_PATH)
	config.set_value("audio_test","preserve","yes")
	config.save(AudioManager.SETTINGS_PATH)
	AudioManager.set_bus_volume("Voice",0.37)
	config.load(AudioManager.SETTINGS_PATH)
	t.check("volume_preserves_other_sections",config.get_value("audio_test","preserve","")=="yes" and is_equal_approx(float(config.get_value("audio","voice",0)),0.37))
	AudioManager.apply_saved_volumes()
	t.check("volume_reloads",is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Voice"))),0.37))
	AudioManager.set_bus_volume("Voice",0.8)
	await t.go_menu()
	await t.seconds(0.4)
func run_windowed(t) -> void:
	await run(t)
	await t.start_world()
	GameManager.set_config_override("time.minutes_per_real_second",0)
	var screen: Control = t.world().game_ui.get_screen(&"dialogue_ui")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/voice/manifest.json"))
	var key := str(manifest.lines["voice/mayor_lyra/greet_2"].text_key)
	var show := func() -> void:await screen.show_lines({"id":"mayor_lyra","name_key":"NPC_MAYOR_LYRA"},[{"text_key":key,"voice_key":"voice/mayor_lyra/greet_2"}])
	show.call()
	await t.seconds(0.5)
	t.tap(&"interact")
	await t.frames(3)
	var peak := AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index("Voice"),0)
	t.check("native_voice_mixer_non_silent",peak>-70 and peak<=1,str(peak)+" dBFS")
	await t.capture("danish_recording_indicator")
	t.tap_key(KEY_ESCAPE)
	await t.frames(3)
	await t.go_menu()
	await t.seconds(0.4)
