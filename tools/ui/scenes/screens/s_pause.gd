extends RefCounted
## scenes/ui/pause_menu.tscn : Esc menu in the same parchment language. Script: scripts/ui/pause_menu.gd

func build(K) -> void:
	var r = K.begin("Control", "PauseMenu", "res://scripts/ui/pause_menu.gd")
	K.full(r)
	var scrim = K.add(r, "ColorRect", "Scrim", {"color": Color(0.11, 0.129, 0.22, 0.62)})
	K.full(scrim)
	var panel = K.panel(r, "PanelContainer", "PanelMenu", {"min": Vector2(380, 0)}, true)
	K.pin(panel, "c", 0, 0)
	var v = K.vbox(panel, "Buttons", 10)
	K.lbl(v, "PauseTitle", "Pause", "Display34", {"horizontal_alignment": HORIZONTAL_ALIGNMENT_CENTER}, true)
	K.btn(v, "ResumeButton", "Fortsæt", "ButtonPrimary", {}, true)
	K.btn(v, "SaveButton", "Gem", "ButtonTertiary", {}, true)
	K.btn(v, "LoadButton", "Indlæs spil", "ButtonTertiary", {}, true)
	K.btn(v, "SettingsButton", "Indstillinger", "ButtonTertiary", {}, true)
	K.btn(v, "QuitButton", "Til titelskærmen", "ButtonTertiary", {}, true)
	K.save("res://scenes/ui/pause_menu.tscn")
