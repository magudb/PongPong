class_name SecretGardenMarker
extends Interactable2D
## Painted, revisitable garden work and evidence. Cancelling a page performs
## no work; quest progress commits only after an explicit completed choice.
var kind := ""
var area: IsoArea
var cell := Vector2i.ZERO
var _pictures: Array[Node2D] = []
var _busy := false
var _player: Node2D
var _screen: Node
var _request: RefCounted
var _talk_generation := -1
var _look := ""
var _leaving := false

static func create_marker(params: Dictionary, _pos: Vector2, at: Vector2i, target: IsoArea) -> Node:
	var marker := SecretGardenMarker.new()
	marker.kind = str(params.get("kind", "gate"))
	marker.area = target
	marker.cell = at
	marker.prompt_key = "SG_TRACE_PROMPT" if marker.kind == "trail" else "SG_PROMPT"
	return marker

func _ready() -> void:
	super._ready()
	refresh()

func _enter_tree() -> void:
	_leaving = false
	EventBus.quest_objective_updated.connect(_progress)
	EventBus.quest_accepted.connect(_quest)
	EventBus.quest_completed.connect(_quest)
	EventBus.day_started.connect(_morning)
	EventBus.load_completed.connect(_loaded)
	if is_node_ready():
		refresh.call_deferred()

func _progress(player_id: StringName, id: StringName, _objective: StringName, _current: int, _target: int) -> void:
	_quest(player_id, id)

func _quest(_player_id: StringName, id: StringName) -> void:
	if id == SecretGardenStory.QUEST:
		refresh()

func _morning(_day: int, _season: StringName) -> void:
	refresh()

func _loaded(_slot: int) -> void:
	refresh()

func refresh() -> void:
	if _leaving or not is_inside_tree():
		return
	var stage := SecretGardenStory.step()
	set_enabled(kind != "trail" or SecretGardenStory.has_evidence("lift_record"))
	var art := ""
	match kind:
		"path": art = "bush_farm" if stage < 1 else ""
		"bench": art = "plank_stack" if stage < 4 else "bench"
		"beds": art = "bush_farm" if stage < 5 else ("crop_moonflower_3" if SecretGardenStory.bloom_ready() else ("crop_moonflower_1" if stage >= 6 else "crop_moonflower_0"))
		"letter": art = "seed_basket"
		"gate": art = "notice_board"
		"trail": art = "seed_basket" if SecretGardenStory.has_evidence("lift_record") else ""
	var count := 6 if kind in ["path", "beds"] else 1
	if kind == "beds":
		for i in count:
			var bed := cell + Vector2i(i % 3 - 1, floori(i / 3.0))
			if stage < 5:
				area.reset_terrain(bed)
			else:
				area.set_terrain(bed, &"soil_watered" if stage >= 6 else &"soil_tilled")
	var look := art + ":" + str(count)
	if _look == look:
		return
	_look = look
	for picture in _pictures:
		if is_instance_valid(picture):
			picture.queue_free()
	_pictures.clear()
	if art == "":
		return
	var painting := ArtCatalog.prop(StringName(art))
	for i in count:
		var sprite := Sprite2D.new()
		sprite.texture = painting.texture
		sprite.centered = false
		sprite.offset = -(painting.pivot as Vector2)
		# Decorations are siblings under the area's y-sort, preserving native
		# cutout pivots. They add no invisible blocker to a restored path.
		var at := cell + Vector2i(i % 3 - 1, floori(i / 3.0)) if count > 1 else cell
		var footprint: Vector2i = painting.footprint
		sprite.position = Iso.iso_footprint_center(at, footprint.x, footprint.y) if area.projection == &"iso" else area.to_local(area.cell_to_global(at))
		area.objects.add_child(sprite)
		_pictures.append(sprite)

func interact(player: Node) -> void:
	if not is_instance_valid(player): return
	var id := PlayerRegistry.registered_id(player)
	if id == &"": return
	var origin := EventBus.interaction_origin(id, self, player)
	if _busy or not is_enabled() or GameManager.is_modal_open() or not EventBus.interaction_body_current(origin, self, player): return
	var screen := LifeFlow.screen(get_tree())
	if screen == null: return
	var request: RefCounted = screen.create_request()
	_screen = screen
	_request = request
	_player = player
	_busy = true
	_talk_generation = int(player.talk_generation) + 1
	_present_owned(weakref(self), weakref(player), origin, screen, request, _talk_generation, global_position, kind, str(area.map.id))

static func _build_owned(kind: String, area_id: String, origin: Dictionary) -> Dictionary:
	if not EventBus.interaction_current(origin): return {}
	var expected := SecretGardenStory.step()
	var can_work := expected >= 0 and expected < SecretGardenStory.STEPS.size() and str(SecretGardenStory.STEPS[expected].get("kind", "")) == kind
	if expected == 10 and area_id != "moerkeskoven":
		can_work = false
	if expected == 6 and not SecretGardenStory.bloom_ready():
		can_work = false
	var key := SecretGardenStory.guide_key()
	if kind == "letter" and SecretGardenStory.has_evidence("letter_watermark"):
		key = "SG_LETTER"
	elif kind == "trail" and SecretGardenStory.has_evidence("garden_trail"):
		key = "SG_TRAIL"
	elif can_work:
		key = "SG_SCENE_" + str(SecretGardenStory.STEPS[expected].id).to_upper()
	var choices: Array = []
	if expected < 0 and QuestManager.is_offerable(SecretGardenStory.QUEST):
		choices.append({"text_key": "SG_START", "action": "garden_start"})
	elif can_work:
		choices.append({"text_key": "SG_DO_" + str(SecretGardenStory.STEPS[expected].id).to_upper(), "action": "garden_work"})
	choices.append({"text_key": "REL_TALK_GOODBYE", "action": "close"})
	if not EventBus.interaction_current(origin): return {}
	return {"expected": expected, "can_work": can_work, "lines": [{"text_key": key}], "choices": choices}

static func _present_owned(actor_ref: WeakRef, body_ref: WeakRef, origin: Dictionary, screen: Node, request: RefCounted, hold: int, at: Vector2, kind: String, area_id: String) -> void:
	var page: Dictionary = PlayerRegistry.for_player(origin.recipient.player_id, func(): return _build_owned(kind, area_id, origin))
	var actor: Variant = actor_ref.get_ref()
	var body: Variant = body_ref.get_ref()
	if not page.is_empty() and EventBus.interaction_body_current(origin, actor, body):
		if body.has_method("begin_talk"): body.begin_talk(at)
		actor = actor_ref.get_ref()
		body = body_ref.get_ref()
		if EventBus.interaction_body_current(origin, actor, body):
			actor = null
			body = null
			screen.request_lines({"id": "", "name_key": "SG_NAME"}, page.lines, page.choices, request)
			var result: Dictionary = await screen.wait_request(request)
			if bool(result.get("completed", false)) and EventBus.interaction_current(origin):
				actor = actor_ref.get_ref()
				body = body_ref.get_ref()
				# Observations are already earned; construction, planting,
				# following and new quest acceptance still require the body.
				var physical := EventBus.interaction_body_current(origin, actor, body)
				var action := str(LuaData.dict(result.get("choice", {})).get("action", ""))
				if action == "garden_work" and bool(page.can_work) and (int(page.expected) in [6, 7] or physical):
					PlayerRegistry.for_player(origin.recipient.player_id, func(): SecretGardenStory.advance_owned(int(page.expected), origin))
				elif action == "garden_start" and physical:
					PlayerRegistry.for_player(origin.recipient.player_id, func():
						if SecretGardenStory.step() < 0 and EventBus.interaction_current(origin) and QuestManager.is_offerable(SecretGardenStory.QUEST) and EventBus.interaction_current(origin):
							QuestManager.accept_quest_owned(SecretGardenStory.QUEST, origin))
	actor = actor_ref.get_ref()
	if is_instance_valid(actor):
		actor._release(hold)
		actor = actor_ref.get_ref()
		if is_instance_valid(actor) and EventBus.interaction_current(origin): actor.refresh()

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
	EventBus.quest_objective_updated.disconnect(_progress)
	EventBus.quest_accepted.disconnect(_quest)
	EventBus.quest_completed.disconnect(_quest)
	EventBus.day_started.disconnect(_morning)
	EventBus.load_completed.disconnect(_loaded)
	var screen := _screen
	var request := _request
	_release()
	if is_instance_valid(screen) and request != null: screen.close_request(request)
	for picture in _pictures:
		if is_instance_valid(picture):
			picture.queue_free()
	_pictures.clear()
	_look = ""
