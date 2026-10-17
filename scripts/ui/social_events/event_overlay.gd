extends Control
## Read-only cinematic bars. The existing dialogue panel owns text and choice focus.
var _asking := false
var _hint: Label
var _confirm_layer: CanvasLayer
var _fade: ColorRect
var _fade_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = MOUSE_FILTER_IGNORE
	_fade = ColorRect.new()
	_fade.color = Color(0,0,0,0)
	_fade.mouse_filter = MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_fade)
	for bottom in [false,true]:
		var bar := ColorRect.new()
		bar.color = Color(0.1686,0.1373,0.251,0.85)
		bar.mouse_filter = MOUSE_FILTER_IGNORE
		bar.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE if bottom else PRESET_TOP_WIDE)
		bar.offset_top = -72 if bottom else 0
		bar.offset_bottom = 0 if bottom else 72
		add_child(bar)
	_hint = Label.new()
	_hint.theme_type_variation = &"Eyebrow"
	_hint.set_meta("tt_override_ok","Cream text on the cinematic ink bar; inherits the guide's Eyebrow font and size")
	_hint.add_theme_color_override("font_color",Color("f4e6c4"))
	_hint.set_anchors_and_offsets_preset(PRESET_BOTTOM_RIGHT)
	_hint.offset_left = -340
	_hint.offset_right = -28
	_hint.offset_top = -48
	_hint.offset_bottom = -20
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_hint)
	_confirm_layer = CanvasLayer.new()
	_confirm_layer.layer = 12
	add_child(_confirm_layer)
	EventBus.modal_changed.connect(func(_stack): _refresh())
	UiNav.watcher().device_changed.connect(func(_device): _refresh())
	_refresh()
	preload("res://scripts/ui/dev/ui_fixtures.gd").register_setup("event_overlay",Callable(get_script(),&"fixture_setup"))

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): _refresh()

func _refresh() -> void:
	visible = GameManager.is_modal_open(&"event")
	if not visible: fade_to(0.0,0.0)
	_hint.text = UiHints.format("SOC_EV_SKIP_HINT",&"ui_cancel")

func fade_to(alpha: float, seconds: float) -> void:
	if _fade_tween != null and _fade_tween.is_running(): _fade_tween.kill()
	if seconds <= 0.0: _fade.color.a = alpha
	else:
		_fade_tween = create_tween()
		_fade_tween.tween_property(_fade,"color:a",alpha,seconds)

func _input(event: InputEvent) -> void:
	if visible and GameManager.top_modal() == &"event" and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause")):
		get_viewport().set_input_as_handled()
		request_skip()

func request_skip() -> void:
	if _asking or not GameManager.is_modal_open(&"event"): return
	_asking = true
	var host := Control.new()
	host.mouse_filter = MOUSE_FILTER_IGNORE
	_confirm_layer.add_child(host)
	host.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var yes := await UiConfirm.ask(host,"SOC_EV_TITLE","SOC_EV_SKIP_QUESTION","SOC_EV_SKIP","SOC_EV_CONTINUE",&"cancel")
	host.queue_free()
	_asking = false
	if yes:
		var director := SocialManager.get_node_or_null("EventDirector")
		if director != null: director.runner.skip()

static func fixture_setup(_node: Node, _host: Node) -> void:
	GameManager.push_modal(&"event",false)
