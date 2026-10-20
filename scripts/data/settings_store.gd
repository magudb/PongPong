class_name SettingsStore
extends RefCounted
## The one reader and writer of user://settings.cfg. Its owners keep their own sections: [game] locale (LocalizationManager),
## [game] pause_on_focus_loss, [video] (SettingsUI), [audio] (AudioManager), [updates] (ReleaseUpdates).
##
## Every write is load-modify-save, so the other owners' sections survive. A file that exists but cannot be read (a parse error, or a
## sync client such as OneDrive holding a lock for a moment) is never overwritten: saving the half-empty ConfigFile would wipe every
## other setting. The write is refused with a warning and the caller's value stays live for this session only.

const PATH := "user://settings.cfg"


## The saved settings; an empty ConfigFile when the file is missing or unreadable (callers read with their own defaults).
static func read() -> ConfigFile:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		config.clear()
	return config


static func value(section: String, key: String, default: Variant = null) -> Variant:
	return read().get_value(section, key, default)


## Writes one value. False (with a warning that names `what`) when the file is unreadable or could not be written.
static func store(section: String, key: String, data: Variant, what: String = "") -> bool:
	return store_all({section: {key: data}}, what)


## Writes {section: {key: value}} in ONE load-modify-save.
static func store_all(values: Dictionary, what: String = "") -> bool:
	var config := ConfigFile.new()
	var err := config.load(PATH)
	var label := what if what != "" else "setting"
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("SettingsStore: %s is unreadable (error %d); the %s was not saved so that no other setting is destroyed" % [PATH, err, label])
		return false
	for section in values:
		var keys: Dictionary = values[section]
		for key in keys:
			config.set_value(str(section), str(key), keys[key])
	var save_err := config.save(PATH)
	if save_err != OK:
		push_warning("SettingsStore: could not write %s (error %d); the %s was not saved" % [PATH, save_err, label])
		return false
	return true
