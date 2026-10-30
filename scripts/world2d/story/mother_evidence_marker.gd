class_name MotherEvidenceMarker
extends Interactable2D
var evidence_id := ""
var cell := Vector2i.ZERO
var area: IsoArea
var _busy := false
var _leaving := false
var _player: Node
var _screen: Node
var _origin: Dictionary = {}
var _request: RefCounted
var _talk_generation := -1
var _picture: Sprite2D
var _keepsake: Sprite2D
var _flowers: Array[Sprite2D] = []
var _echo: Sprite2D
var _lamp_light: Sprite2D
var _stitches: Array[Line2D] = []
var _name_label: Label
var _route_arrow: Line2D
const ECHO_IDS := ["traveller_account", "mother_fate"]
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): refresh()
func _enter_tree() -> void:
	_leaving = false
	if is_node_ready(): refresh.call_deferred()
func _ready() -> void:
	prompt_key = "FM_INSPECT"
	radius = Vector2(82,48)
	super._ready()
	var row := MotherStory.definition(evidence_id)
	if evidence_id == "marked_lamp": _prop(&"mother_route_map",Vector2(35,5))
	if evidence_id == "mother_fate": _keepsake = _prop(&"mother_seed_tin",Vector2(105,18))
	var art_id := StringName(str(row.get("art","")))
	if ArtCatalog.has_real_prop(art_id):
		_picture = _prop(art_id,Vector2.ZERO)
	if evidence_id in ECHO_IDS:
		_echo = Sprite2D.new()
		_echo.texture = Glow.halo_texture()
		_echo.material = Glow.additive_material()
		_echo.modulate = Color("8fb0e8")
		_echo.scale = Vector2(1.4, 1.4)
		_echo.position = Vector2(0, -52)
		add_child(_echo)
	if evidence_id == "memory_lamp":
		_lamp_light = Sprite2D.new()
		_lamp_light.texture = Glow.halo_texture()
		_lamp_light.material = Glow.additive_material()
		_lamp_light.position = Vector2(0, -45)
		_lamp_light.modulate = Color("f5d393", 0.65)
		add_child(_lamp_light)
		for index in 3:
			var stitch := Line2D.new()
			stitch.points = PackedVector2Array([Vector2(-10, -83+index*7), Vector2(1, -89+index*7)])
			stitch.width = 3
			add_child(stitch)
			_stitches.append(stitch)
	if evidence_id == "traveller_account":
		_name_label = Label.new()
		_name_label.theme = load("res://assets/ui/theme.tres")
		_name_label.theme_type_variation = &"Display20"
		_name_label.position = Vector2(-70, -155)
		_name_label.size.x = 140
		_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(_name_label)
	if evidence_id == "route_stone":
		_route_arrow = Line2D.new()
		_route_arrow.points = PackedVector2Array([Vector2(-30, 0), Vector2(30, 0), Vector2(15, -12), Vector2(30, 0), Vector2(15, 12)])
		_route_arrow.width = 4
		_route_arrow.default_color = Color("f5d393")
		_route_arrow.position = Vector2(0, -35)
		add_child(_route_arrow)
	refresh()
func _prop(id: StringName,at: Vector2) -> Sprite2D:
	var art := ArtCatalog.prop(id)
	var sprite := Sprite2D.new()
	sprite.texture = art.texture
	sprite.centered = false
	sprite.offset = -Vector2(art.pivot)
	sprite.position = at
	add_child(sprite)
	return sprite
func refresh() -> void:
	set_enabled(MotherStory.enabled() and (evidence_id != "legacy_home" or MotherStory.has("mother_fate")))
	if _echo != null: _echo.visible = is_enabled()
	if evidence_id == "echo_account": set_enabled(MotherStory.can_read(evidence_id))
	if evidence_id == "memory_map":
		set_enabled(MotherStory.can_read(evidence_id))
		if _picture != null: _picture.visible = is_enabled()
	if _lamp_light != null:
		_lamp_light.visible = MotherMemoryWork.complete(evidence_id)
		for index in _stitches.size():
			_stitches[index].default_color = Color("f5d393") if MotherMemoryWork.complete(evidence_id) or MotherMemoryWork.state(evidence_id) & (1 << index) != 0 else Color("635751")
	if _name_label != null: _name_label.text = tr("FM_WORK_NAME_IVA" if MotherMemoryWork.complete(evidence_id) else "FM_WORK_NAME_GUEST")
	if _route_arrow != null: _route_arrow.rotation = (MotherMemoryWork.state(evidence_id) % 4 - 1) * PI / 2
	if _keepsake != null: _keepsake.visible = not MotherStory.has("mother_fate")
	if evidence_id == "legacy_home" and MotherStory.has("legacy_home") and _flowers.is_empty():
		var art := ArtCatalog.prop(&"crop_moonflower_3")
		for index in 3:
			var flower := Sprite2D.new()
			flower.texture = art.texture
			flower.centered = false
			flower.offset = -Vector2(art.pivot)
			flower.position = [Vector2(-100,20),Vector2(100,20),Vector2(0,110)][index]
			add_child(flower)
			_flowers.append(flower)
func _lines() -> Array:
	if evidence_id == "echo_account": return [{"text_key":"FM_FIELD_NOTE"},{"text_key":"FM_E_ECHO_ACCOUNT_TEXT"}]
	if evidence_id == "traveller_account":
		return [{"name_key":"FM_SCRIBE_NAME","text_key":"FM_SCRIBE_TRAVELLER_1"},{"name_key":"FM_SCRIBE_NAME","text_key":"FM_SCRIBE_TRAVELLER_2"},{"text_key":"FM_E_TRAVELLER_ACCOUNT_TEXT"}]
	if evidence_id == "mother_fate":
		return [{"name_key":"FM_SCRIBE_NAME","text_key":"FM_SCRIBE_FINAL_OFFER"},{"text_key":"FM_FINAL_ACCOUNT"},{"text_key":"FM_FINAL_TRUTH"},{"text_key":"FM_FINAL_BARGAIN"}]
	return [{"text_key":MotherStory.evidence_text_key(evidence_id)}]
func interact(player: Node) -> void:
	if not is_instance_valid(player): return
	var id := PlayerRegistry.registered_id(player)
	if id == &"": return
	var origin := EventBus.interaction_origin(id, self, player)
	if _busy or not is_enabled() or GameManager.is_modal_open() or not EventBus.interaction_body_current(origin, self, player): return
	var screen := LifeFlow.screen(get_tree())
	if screen == null: return
	# Reserve the exact receipt before begin_talk or any presentation callback.
	var request: RefCounted = screen.create_request()
	_screen = screen
	_request = request
	_origin = origin
	_busy = true
	_player = player
	_talk_generation = int(player.talk_generation) + 1
	_present_owned(weakref(self), weakref(player), evidence_id, origin, screen, request, _talk_generation, global_position)

## Static so an earned terminal receipt survives actual marker destruction.
static func _present_owned(actor_ref: WeakRef, body_ref: WeakRef, id: String, origin: Dictionary, screen: Node, request: RefCounted, hold: int, at: Vector2) -> void:
	var actor: Variant = actor_ref.get_ref()
	var body: Variant = body_ref.get_ref()
	if not EventBus.interaction_body_current(origin, actor, body): return
	if body.has_method("begin_talk"): body.begin_talk(at)
	var feedback := ""
	while true:
		actor = actor_ref.get_ref()
		body = body_ref.get_ref()
		if not EventBus.interaction_body_current(origin, actor, body): break
		var page: Dictionary = PlayerRegistry.for_player(origin.recipient.player_id, func():
			var work := id in MotherMemoryWork.IDS and MotherStory.enabled() and not MotherMemoryWork.complete(id)
			if not EventBus.interaction_current(origin): return {}
			if work:
				var lines: Array = [{"text_key": MotherMemoryWork.instructions(id)}]
				if feedback != "": lines.append({"text_key": feedback})
				return {"work": true, "lines": lines, "choices": MotherMemoryWork.choices(id)}
			var may_record := MotherStory.can_read(id)
			if not EventBus.interaction_current(origin): return {}
			var choices: Array = []
			var lines: Array = actor._lines() if may_record else [{"text_key": MotherStory.next_lead()}]
			if may_record and not MotherStory.has(id):
				var key: String = {"mother_fate": "FM_REFUSE_ROLE", "legacy_home": "FM_PLANT_LEGACY", "traveller_account": "FM_RETURN_NAME"}.get(id, "FM_RECORD")
				choices.append({"text_key": key, "action": "mother_record"})
			choices.append({"text_key": "REL_TALK_GOODBYE", "action": "close"})
			return {"work": false, "may_record": may_record, "lines": lines, "choices": choices})
		actor = actor_ref.get_ref()
		body = body_ref.get_ref()
		if page.is_empty() or not EventBus.interaction_body_current(origin, actor, body): break
		var portrait: Texture2D = actor._picture.texture if actor._picture != null else null
		actor._request = request
		actor = null
		body = null
		screen.request_lines({"id": "", "name_key": "FM_NAME", "portrait": portrait}, page.lines, page.choices, request)
		var result: Dictionary = await screen.wait_request(request)
		var action := str(LuaData.dict(result.get("choice", {})).get("action", "close"))
		if not bool(page.work):
			# Reading/recording evidence is earned by the completed page. It is
			# not new physical work, and body/marker departure does not revoke it.
			if bool(result.get("completed", false)) and action == "mother_record" and bool(page.may_record) and EventBus.interaction_current(origin):
				PlayerRegistry.for_player(origin.recipient.player_id, func(): MotherStory.record_owned(id, origin))
			break
		actor = actor_ref.get_ref()
		body = body_ref.get_ref()
		if not bool(result.get("completed", false)) or action == "close" or not EventBus.interaction_body_current(origin, actor, body): break
		feedback = PlayerRegistry.for_player(origin.recipient.player_id, func(): return MotherMemoryWork.apply_owned(id, action, origin))
		actor = actor_ref.get_ref()
		body = body_ref.get_ref()
		if not EventBus.interaction_body_current(origin, actor, body): break
		actor.refresh()
		request = screen.create_request()
	actor = actor_ref.get_ref()
	if is_instance_valid(actor):
		actor._release(hold)
		if EventBus.interaction_current(origin) and actor.is_inside_tree(): actor.refresh()

func _release(expected: int = -1) -> void:
	if expected != -1 and expected != _talk_generation: return
	var body: Variant = _player
	var hold := _talk_generation
	_player = null
	_request = null
	_busy = false
	_talk_generation = -1
	if is_instance_valid(body) and body.get("talk_generation") == hold and body.get("state") == PlayerBody2D.S.TALKING and body.has_method("end_talk"): body.end_talk()

func _exit_tree() -> void:
	_leaving = true
	var screen := _screen
	var request := _request
	_release()
	if is_instance_valid(screen) and request != null: screen.close_request(request)
