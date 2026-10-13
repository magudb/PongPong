extends Node
## Handles Danish-first localization, runtime lookups, and voice key mapping.

const LOCALE_DA := "da"
const LOCALE_EN := "en"

var current_locale: String = LOCALE_DA
var voice_enabled: bool = true
var voice_volume_db: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_locale(LOCALE_DA)


func set_locale(locale: String) -> void:
	current_locale = locale
	TranslationServer.set_locale(locale)
	EventBus.notification_posted.emit(
		tr("NOTIF_LANGUAGE_CHANGED_TITLE"),
		tr("NOTIF_LANGUAGE_CHANGED_MSG"),
		"language"
	)


func t(key: String, args: Array = []) -> String:
	var text := tr(key)
	if args.size() > 0:
		return text % args
	return text


## Voice keys map 1:1 to audio files under assets/audio/voice/
func voice_key_for(speaker_id: String, line_id: String) -> String:
	return "voice/%s/%s" % [speaker_id, line_id]


func play_voice(speaker_id: String, line_id: String) -> void:
	if not voice_enabled:
		return
	AudioManager.play_voice(voice_key_for(speaker_id, line_id), voice_volume_db)


func is_da() -> bool:
	return current_locale == LOCALE_DA
