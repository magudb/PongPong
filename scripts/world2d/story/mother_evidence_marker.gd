class_name MotherEvidenceMarker
extends Interactable2D
var evidence_id := ""
var cell := Vector2i.ZERO
var area: IsoArea
var _busy := false
var _leaving := false
var _ticket: RefCounted
var _origin: RefCounted
var _player: Node
var _screen: Node
var _picture: Sprite2D
var _keepsake: Sprite2D
var _flowers: Array[Sprite2D] = []
var _echo: Sprite2D
var _lamp_light: Sprite2D
var _stitches: Array[Line2D] = []
var _name_label: Label
var _route_arrow: Line2D
var _refresh_revision := 0
# Director-created readiness belongs to its allocating root, including callbacks
# between add_child and _ready. Independent refreshes retain their own receipts.
var _ready_guard: Callable
var _ready_art_complete := false
const ECHO_IDS := ["traveller_account", "mother_fate"]
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): refresh()
func _enter_tree() -> void:
	_leaving = false
	if is_node_ready(): _refresh_origin.call_deferred(SecretGardenMarker.refresh_guard(self, area, true))
func _ready() -> void:
	var current := _ready_guard if _ready_guard.is_valid() else SecretGardenMarker.refresh_guard(self, area, true)
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
	_ready_art_complete = true
	_refresh_origin(current)
	if current.is_valid() and not current.call(): _refresh_origin.call_deferred(current)
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
	_refresh_origin(SecretGardenMarker.refresh_guard(self, area))

func _refresh_origin(current: Callable, pid: StringName = &"p0") -> void:
	if not current.is_valid() or not current.call() or _leaving: return
	if not _ready_art_complete:
		_refresh_origin.call_deferred(current, pid)
		return
	_refresh_revision += 1
	var revision := _refresh_revision
	var owner_ref: WeakRef = weakref(self)
	var area_ref: WeakRef = weakref(area)
	var owned := func() -> bool:
		var owner: Variant = owner_ref.get_ref()
		var place: Variant = area_ref.get_ref()
		var scene := PlayerRegistry.world()
		return current.call() and is_instance_valid(owner) and owner.is_inside_tree() and not owner.is_queued_for_deletion() and not owner._leaving and owner._refresh_revision == revision and is_instance_valid(place) and place.is_ancestor_of(owner) and is_instance_valid(scene) and scene.area == place
	PlayerRegistry.for_player(pid, func(): _paint_refresh(owned))

func _paint_refresh(current: Callable) -> void:
	if not current.call(): return
	# Resolve every lazy reader before publishing visibility/child callbacks.
	var enabled := MotherStory.enabled() and (evidence_id != "legacy_home" or MotherStory.has("mother_fate"))
	var readable := MotherStory.can_read(evidence_id) if evidence_id in ["echo_account", "memory_map"] else enabled
	var complete := MotherMemoryWork.complete(evidence_id)
	var work := MotherMemoryWork.state(evidence_id)
	var fate := MotherStory.has("mother_fate")
	var legacy := evidence_id == "legacy_home" and MotherStory.has("legacy_home")
	if not current.call(): return
	set_enabled(enabled)
	if not current.call(): return
	if _echo != null:
		_echo.visible = is_enabled()
		if not current.call(): return
	if evidence_id in ["echo_account", "memory_map"]:
		set_enabled(readable)
		if not current.call(): return
	if evidence_id == "memory_map" and _picture != null:
		_picture.visible = is_enabled()
		if not current.call(): return
	if _lamp_light != null:
		_lamp_light.visible = complete
		if not current.call(): return
		for index in _stitches.size():
			_stitches[index].default_color = Color("f5d393") if complete or work & (1 << index) != 0 else Color("635751")
			if not current.call(): return
	if _name_label != null:
		_name_label.text = tr("FM_WORK_NAME_IVA" if complete else "FM_WORK_NAME_GUEST")
		if not current.call(): return
	if _route_arrow != null:
		_route_arrow.rotation = (work % 4 - 1) * PI / 2
		if not current.call(): return
	if _keepsake != null:
		_keepsake.visible = not fate
		if not current.call(): return
	if not legacy:
		for flower in _flowers:
			if is_instance_valid(flower): flower.queue_free()
		_flowers.clear()
	else:
		var art := ArtCatalog.prop(&"crop_moonflower_3")
		for index in range(_flowers.size(), 3):
			if not current.call(): return
			var flower := Sprite2D.new()
			flower.texture = art.texture
			flower.centered = false
			flower.offset = -Vector2(art.pivot)
			flower.position = [Vector2(-100,20),Vector2(100,20),Vector2(0,110)][index]
			_flowers.append(flower)
			add_child(flower)
			if not current.call(): return
func _lines() -> Array:
	if evidence_id == "echo_account": return [{"text_key":"FM_FIELD_NOTE"},{"text_key":"FM_E_ECHO_ACCOUNT_TEXT"}]
	if evidence_id == "traveller_account":
		return [{"name_key":"FM_SCRIBE_NAME","text_key":"FM_SCRIBE_TRAVELLER_1"},{"name_key":"FM_SCRIBE_NAME","text_key":"FM_SCRIBE_TRAVELLER_2"},{"text_key":"FM_E_TRAVELLER_ACCOUNT_TEXT"}]
	if evidence_id == "mother_fate":
		return [{"name_key":"FM_SCRIBE_NAME","text_key":"FM_SCRIBE_FINAL_OFFER"},{"text_key":"FM_FINAL_ACCOUNT"},{"text_key":"FM_FINAL_TRUTH"},{"text_key":"FM_FINAL_BARGAIN"}]
	return [{"text_key":MotherStory.evidence_text_key(evidence_id)}]
func interact(player: Node) -> void:
	if not SecretGardenMarker.interaction_attached(self, area): return
	if _busy or not is_enabled() or GameManager.is_modal_open(): return
	_screen = LifeFlow.screen(get_tree())
	if _screen == null: return
	_origin = preload("res://scripts/traetoppen/life/presenter_origin.gd").capture(self, player)
	if _origin == null: return
	var origin := _origin
	_busy = true
	_player = player
	# Query phases use the retained owner only for their synchronous duration.
	# In particular the work loop must re-enter that same scope after each await.
	if evidence_id in MotherMemoryWork.IDS and _origin.call_owned(func(): return MotherStory.enabled() and not MotherMemoryWork.complete(evidence_id)):
		var feedback := ""
		while not _leaving and is_inside_tree() and _origin.current() and _origin.call_owned(func(): return not MotherMemoryWork.complete(evidence_id)):
			var work_page: Dictionary = _origin.call_owned(func(): return {"lines":[{"text_key":MotherMemoryWork.instructions(evidence_id)}], "choices":MotherMemoryWork.choices(evidence_id)})
			var work_lines: Array = work_page.lines
			if feedback != "": work_lines.append({"text_key":feedback})
			var work_portrait: Texture2D = _picture.texture if _picture != null else null
			var response: Array = []
			_ticket = _origin.earned_page(self, _screen, {"id":"", "name_key":"FM_NAME", "portrait":work_portrait}, work_lines, work_page.choices, global_position, _finish_work.bind(evidence_id, response))
			if _ticket == null:
				_release()
				return
			var work_result: Dictionary = await _ticket.wait()
			var action := str(LuaData.dict(work_result.get("choice", {})).get("action", "close"))
			if _leaving or not is_inside_tree() or not _origin.current() or not bool(work_result.get("completed", false)) or action == "close":
				_release()
				return
			feedback = str(response[0]) if not response.is_empty() else ""
			_refresh_origin(origin.current, origin.pid)
	if _leaving or not is_inside_tree() or not _origin.current():
		_release()
		return
	var page: Dictionary = _origin.call_owned(_record_page)
	var portrait: Texture2D = _picture.texture if _picture != null else null
	_ticket = _origin.earned_page(self, _screen, {"id":"","name_key":"FM_NAME","portrait":portrait}, page.lines, page.choices, global_position, _finish_record.bind(evidence_id, page.may_record))
	if _ticket != null: await _ticket.wait()
	if not _leaving and is_inside_tree() and origin.current(): _refresh_origin(origin.current, origin.pid)
	_release()

func _record_page() -> Dictionary:
	var may_record := MotherStory.can_read(evidence_id)
	var choices: Array = []
	var lines := _lines() if may_record else [{"text_key":MotherStory.next_lead()}]
	if may_record and not MotherStory.has(evidence_id):
		var key := "FM_RECORD"
		if evidence_id == "mother_fate": key = "FM_REFUSE_ROLE"
		elif evidence_id == "legacy_home": key = "FM_PLANT_LEGACY"
		elif evidence_id == "traveller_account": key = "FM_RETURN_NAME"
		choices.append({"text_key":key,"action":"mother_record"})
	choices.append({"text_key":"REL_TALK_GOODBYE","action":"close"})
	return {"may_record":may_record, "lines":lines, "choices":choices}
static func _finish_work(result: Dictionary, effects_current: Callable, id: String, response: Array) -> void:
	var action := str(LuaData.dict(result.get("choice", {})).get("action", "close"))
	if bool(result.get("completed", false)) and action != "close": response.append(MotherMemoryWork.apply_owned(id, action, effects_current))

static func _finish_record(result: Dictionary, effects_current: Callable, id: String, may_record: bool) -> void:
	if bool(result.get("completed", false)) and str(LuaData.dict(result.get("choice", {})).get("action", "")) == "mother_record" and may_record: MotherStory.record_owned(id, effects_current)

func _release() -> void:
	# Travel/damage must not clear a newer player state.
	# DialogueUI releases only this request's hold before terminal observers.
	_player = null
	_busy = false
func _exit_tree() -> void:
	_leaving = true
	if _busy and is_instance_valid(_screen): _screen.close_owned(_ticket)
	_release()
