extends RefCounted
const SECTION := "persistence_consequential_audio"
const TIMEOUT_S := 30.0
# Execute the existing real retained-Ogg playback shutdown positive controls,
# without audio_town's unrelated tool subprocesses/travel/recipe checks.
func run(t) -> void:
	var original: RefCounted = load("res://tests/sections/audio_town.gd").new()
	await original._shutdown_releases_playbacks(t)
