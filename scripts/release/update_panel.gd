extends TTScreen
const L := preload("res://scripts/ui/social/social_layout.gd")
var service: ReleaseUpdates
var status_label: Label
var version_label: Label
var progress_bar: ProgressBar
var primary: Button
var back: Button
var _confirmed := false

func _init() -> void:
	super._init()
	screen_id = &"updates"
	modal_name = &"updates"
	nested_under = &"settings"

func _ready() -> void:
	super._ready()
	service = ReleaseUpdates.inst()
	L.scrim(self)
	var book := L.panel(self, "PanelParchment", Rect2(300, 180, 680, 360))
	var body := L.box(L.margin(book, 24), true, 14)
	L.label(body, "UPDATE_TITLE", "Display34")
	version_label = L.label(body, "", "Body")
	status_label = L.label(body, "", "Body", true)
	status_label.size_flags_vertical = SIZE_EXPAND_FILL
	progress_bar = ProgressBar.new()
	progress_bar.max_value = 1
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size.y = 18
	body.add_child(progress_bar)
	var buttons := L.box(body, false, 12)
	primary = L.button(buttons, "UPDATE_CHECK", "ButtonPrimary")
	primary.name = "UpdateAction"
	primary.pressed.connect(_action)
	back = L.button(buttons, "UI_CLOSE", "ButtonSecondaryS")
	back.name = "UpdateClose"
	back.pressed.connect(_on_cancel)
	UiNav.wire_ring([primary, back])
	UiNav.hover_focus([primary, back])
	service.changed.connect(_changed)
	_refresh_texts()

func open(opener: Control = null) -> void:
	super.open(opener)
	if is_open() and not service.checked: service.check()

func _initial_focus() -> Control:
	return primary if not primary.disabled else back

func _on_cancel() -> void:
	if service.state == "installing": return
	_confirmed = false
	service.cancel_download()
	close()

func _changed() -> void:
	_refresh_texts()
	if service.state == "ready" and _confirmed:
		_confirmed = false
		service.install()

func _process(delta: float) -> void:
	super._process(delta)
	if is_open() and service.state == "downloading": progress_bar.value = service.progress()

func _refresh_texts() -> void:
	if not is_node_ready() or service == null: return
	version_label.text = tr("UPDATE_VERSION") % ReleaseUpdates.current_version()
	var key := "UPDATE_STATE_" + service.state.to_upper()
	status_label.text = tr(key)
	if service.state in ["available", "ready"]: status_label.text = tr(key) % str(service.available.get("version", ""))
	var installable := not service.install_target().is_empty()
	if not installable and service.state in ["available", "ready"]: status_label.text += "\n" + tr("UPDATE_INSTALLED_ONLY")
	primary.text = tr("UPDATE_INSTALL" if service.state in ["available", "ready", "download_failed"] else "UPDATE_CHECK")
	UiNav.set_enabled(primary, service.state not in ["checking", "downloading", "installing"] and (installable or service.state not in ["available", "ready", "download_failed"]))
	progress_bar.visible = service.state == "downloading"
	UiNav.set_enabled(back, service.state != "installing")

func _action() -> void:
	if service.state in ["available", "ready", "download_failed"]:
		var accepted := await UiConfirm.ask(self, "UPDATE_CONFIRM_TITLE", tr("UPDATE_CONFIRM") % str(service.available.get("version", "")), "UPDATE_INSTALL")
		if not accepted: return
		_confirmed = true
		if service.state == "ready": _changed()
		else: service.download()
	else:
		service.check()
