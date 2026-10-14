extends Label
## Planted defect (locale sweep): shows a translation key that has no English entry - a raw key - ONLY while the language is English. A scan in Danish is clean.


func _ready() -> void:
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh()


func _refresh() -> void:
	text = "NO_SUCH_KEY_EN" if TranslationServer.get_locale().begins_with("en") else "Hej"
