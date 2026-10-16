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

func _progress(id: StringName, _objective: StringName, _current: int, _target: int) -> void:
	_quest(id)

func _quest(id: StringName) -> void:
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
	if _busy or not is_enabled() or GameManager.is_modal_open():
		return
	_screen = LifeFlow.screen(get_tree())
	if _screen == null:
		return
	_busy = true
	_player = player as Node2D
	if is_instance_valid(_player) and _player.has_method("begin_talk"):
		_player.begin_talk(global_position)
	var expected := SecretGardenStory.step()
	var can_work := expected >= 0 and expected < SecretGardenStory.STEPS.size() and str(SecretGardenStory.STEPS[expected].get("kind", "")) == kind
	if expected == 10 and str(area.map.id) != "moerkeskoven":
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
	var result: Dictionary = await _screen.show_lines({"id": "", "name_key": "SG_NAME"}, [{"text_key": key}], choices)
	if _leaving or not is_inside_tree():
		_release()
		return
	if bool(result.get("completed", false)):
		match str(LuaData.dict(result.get("choice", {})).get("action", "")):
			"garden_start":
				if SecretGardenStory.step() < 0 and QuestManager.is_offerable(SecretGardenStory.QUEST):
					QuestManager.accept_quest(SecretGardenStory.QUEST)
			"garden_work":
				if can_work:
					SecretGardenStory.advance(expected)
	_release()
	refresh()

func _release() -> void:
	if is_instance_valid(_player) and _player.has_method("end_talk"):
		_player.end_talk()
	_player = null
	_busy = false

func _exit_tree() -> void:
	_leaving = true
	EventBus.quest_objective_updated.disconnect(_progress)
	EventBus.quest_accepted.disconnect(_quest)
	EventBus.quest_completed.disconnect(_quest)
	EventBus.day_started.disconnect(_morning)
	EventBus.load_completed.disconnect(_loaded)
	if _busy and is_instance_valid(_screen):
		_screen.close()
	_release()
	for picture in _pictures:
		if is_instance_valid(picture):
			picture.queue_free()
	_pictures.clear()
	_look = ""
