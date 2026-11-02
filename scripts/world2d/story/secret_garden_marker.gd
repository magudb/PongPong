class_name SecretGardenMarker
extends Interactable2D
## Painted, revisitable garden work and evidence. Cancelling a page performs
## no work; quest progress commits only after an explicit completed choice.
var kind := ""
var area: IsoArea
var cell := Vector2i.ZERO
var _pictures: Array[Node2D] = []
var _busy := false
var _origin: RefCounted
var _ticket: RefCounted
var _player: Node2D
var _screen: Node
var _look := ""
var _leaving := false
var _refresh_revision := 0

## Environmental reconciliation belongs to the current logical host model, not
## the ambient caller or the old World's physical body after a pending-only load.
## This is noncreating and does not rebind that body's interaction authority.
static func refresh_guard(node: Node, target: IsoArea, staged := false, pid: StringName = &"p0") -> Callable:
	if pid not in [&"p0", &"p1", &"p2", &"p3"]: return Callable()
	var live := func(value: Variant) -> bool:
		return is_instance_valid(value) and value is Node and value.is_inside_tree() and not value.is_queued_for_deletion()
	var model: Variant = PlayerRegistry._states.get(pid)
	var scene: Node = PlayerRegistry.world()
	if not live.call(node) or not live.call(target) or not live.call(scene) or not model is PlayerState: return Callable()
	if model.player_id != pid or model.peer_id < 1 or (pid == &"p0" and model.peer_id != 1) or not "area" in scene or not scene.is_ancestor_of(target) or not scene.is_ancestor_of(node): return Callable()
	# World publishes its target after attaching/building it. Readiness may
	# retain that staged area, but painting still requires its exact publication.
	if scene.area != target and not (staged and scene.area == null): return Callable()
	if node is Interactable2D and not target.is_ancestor_of(node): return Callable()
	var owner_ref: WeakRef = weakref(node)
	var area_ref: WeakRef = weakref(target)
	var world_ref: WeakRef = weakref(scene)
	var profile_ref: WeakRef = weakref(model)
	var incarnation: RefCounted = SocialManager._accounting_world
	return func() -> bool:
		var owner: Variant = owner_ref.get_ref()
		var place: Variant = area_ref.get_ref()
		var world: Variant = world_ref.get_ref()
		return not SocialManager._accounting_suspended and SocialManager._accounting_world == incarnation and profile_ref.get_ref() != null and PlayerRegistry._states.get(pid) == profile_ref.get_ref() and profile_ref.get_ref().player_id == pid and profile_ref.get_ref().peer_id > 0 and (pid != &"p0" or profile_ref.get_ref().peer_id == 1) and live.call(owner) and live.call(place) and live.call(world) and PlayerRegistry.world() == world and world.area == place and world.is_ancestor_of(owner) and (not owner is Interactable2D or place.is_ancestor_of(owner))

static func interaction_attached(node: Node, target: IsoArea) -> bool:
	var current := refresh_guard(node, target)
	if not current.is_valid() or not current.call(): return false
	var scene := PlayerRegistry.world()
	if not ("_host_profile" in scene and scene._host_profile != null): return false
	var model: Variant = PlayerRegistry._states.get(&"p0")
	# Physical attachment binds the body at spawn and is never rebound. A
	# model-only new-game reset ADOPTS the retained body for the new run
	# (session continuity); a load never adopts its successor model (D09:
	# that model must arrive with a re-entered body), so a loaded successor
	# can never act through the old body.
	return scene._host_profile == model or scene._host_reset_adoptee == model

func _refresh_origin(current: Callable, pid: StringName = &"p0") -> void:
	if not current.is_valid() or not current.call() or _leaving: return
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

static func create_marker(params: Dictionary, _pos: Vector2, at: Vector2i, target: IsoArea) -> Node:
	var marker := SecretGardenMarker.new()
	marker.kind = str(params.get("kind", "gate"))
	marker.area = target
	marker.cell = at
	marker.prompt_key = "SG_TRACE_PROMPT" if marker.kind == "trail" else "SG_PROMPT"
	return marker

func _ready() -> void:
	var current := refresh_guard(self, area, true)
	super._ready()
	_refresh_origin(current)
	if current.is_valid() and not current.call(): _refresh_origin.call_deferred(current)

func _enter_tree() -> void:
	_leaving = false
	EventBus.quest_objective_updated.connect(_progress)
	EventBus.quest_accepted.connect(_quest)
	EventBus.quest_completed.connect(_quest)
	EventBus.day_started.connect(_morning)
	EventBus.load_completed.connect(_loaded)
	if is_node_ready():
		_refresh_origin.call_deferred(refresh_guard(self, area, true))

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
	_refresh_origin(refresh_guard(self, area))

func _paint_refresh(current: Callable) -> void:
	if not current.call(): return
	var stage := SecretGardenStory.step()
	var evidence := SecretGardenStory.has_evidence("lift_record")
	var bloom := SecretGardenStory.bloom_ready() if kind == "beds" else false
	if not current.call(): return
	set_enabled(kind != "trail" or evidence)
	if not current.call(): return
	var art := ""
	match kind:
		"path": art = "bush_farm" if stage < 1 else ""
		"bench": art = "plank_stack" if stage < 4 else "bench"
		"beds": art = "bush_farm" if stage < 5 else ("crop_moonflower_3" if bloom else ("crop_moonflower_1" if stage >= 6 else "crop_moonflower_0"))
		"letter": art = "seed_basket"
		"gate": art = "notice_board"
		"trail": art = "seed_basket" if evidence else ""
	var count := 6 if kind in ["path", "beds"] else 1
	if kind == "beds":
		for i in count:
			if not current.call(): return
			var bed := cell + Vector2i(i % 3 - 1, floori(i / 3.0))
			if stage < 5:
				area.reset_terrain(bed)
			else:
				area.set_terrain(bed, &"soil_watered" if stage >= 6 else &"soil_tilled")
	if not current.call(): return
	var look := art + ":" + str(count)
	if _look == look:
		return
	_look = ""
	for picture in _pictures:
		if is_instance_valid(picture):
			picture.queue_free()
	_pictures.clear()
	if art == "":
		_look = look
		return
	var painting := ArtCatalog.prop(StringName(art))
	for i in count:
		if not current.call(): return
		var sprite := Sprite2D.new()
		sprite.texture = painting.texture
		sprite.centered = false
		sprite.offset = -(painting.pivot as Vector2)
		# Decorations are siblings under the area's y-sort, preserving native
		# cutout pivots. They add no invisible blocker to a restored path.
		var at := cell + Vector2i(i % 3 - 1, floori(i / 3.0)) if count > 1 else cell
		var footprint: Vector2i = painting.footprint
		sprite.position = Iso.iso_footprint_center(at, footprint.x, footprint.y) if area.projection == &"iso" else area.to_local(area.cell_to_global(at))
		# Publish ownership before add_child can reenter with a fresh refresh.
		_pictures.append(sprite)
		area.objects.add_child(sprite)
		if not current.call(): return
	_look = look

func interact(player: Node) -> void:
	if not interaction_attached(self, area): return
	if _busy or not is_enabled() or GameManager.is_modal_open():
		return
	_screen = LifeFlow.screen(get_tree())
	if _screen == null:
		return
	_origin = preload("res://scripts/traetoppen/life/presenter_origin.gd").capture(self, player)
	if _origin == null: return
	var origin := _origin
	_busy = true
	_player = player as Node2D
	# Even eligibility readers can lazily install Quest containers. Resolve
	# this page in the authenticated owner's synchronous scope, never the caller's.
	var page: Dictionary = _origin.call_owned(_page_data)
	_ticket = _origin.earned_page(self, _screen, {"id":"", "name_key":"SG_NAME"}, [{"text_key":page.key}], page.choices, global_position, _finish_page.bind(page.expected, page.can_work))
	if _ticket != null: await _ticket.wait()
	_release()
	if not _leaving and is_inside_tree() and origin.current(): _refresh_origin(origin.current, origin.pid)

func _page_data() -> Dictionary:
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
	return {"expected":expected, "can_work":can_work, "key":key, "choices":choices}

static func _finish_page(result: Dictionary, effects_current: Callable, expected: int, can_work: bool) -> void:
	if not bool(result.get("completed", false)): return
	match str(LuaData.dict(result.get("choice", {})).get("action", "")):
		"garden_start":
			if SecretGardenStory.step() < 0 and QuestManager.is_offerable(SecretGardenStory.QUEST): QuestManager.accept_quest_owned(SecretGardenStory.QUEST, effects_current)
		"garden_work":
			if can_work: SecretGardenStory.advance_owned(expected, effects_current)

func _release() -> void:
	# The exact page owns and releases its hold before terminal callbacks.
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
		_screen.close_owned(_ticket)
	_release()
	for picture in _pictures:
		if is_instance_valid(picture):
			picture.queue_free()
	_pictures.clear()
	_look = ""
