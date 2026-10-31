class_name Npc2D
extends CharacterBody2D
## A real painted citizen. Routines drive position; this actor owns interaction and animation.
const Bridge := preload("res://scripts/social/talk/dialogue_bridge.gd")
const C := preload("res://scripts/ui/theme/tt_colors.gd")
class WalkTicket extends RefCounted:
	signal finished(completed: bool)

class BubbleLabel extends Label:
	var candle := false
	func _draw() -> void:
		if not candle:
			return
		draw_rect(Rect2(10, 7, 12, 21), C.INK)
		draw_rect(Rect2(12, 9, 8, 17), C.CHALK)
		draw_line(Vector2(16, 7), Vector2(16, 3), C.INK, 2)
		draw_colored_polygon(PackedVector2Array([Vector2(16, -6), Vector2(12, 1), Vector2(16, 4), Vector2(20, 1)]), C.HONEY)
var npc_id: StringName = &""
var dialogue_id: StringName = &""
var display_name_key := ""
var visual: IsoChibiSprite2D
var area: IsoArea
var is_talking := false
var driven := false
var wander_radius := 0.0
var routine_id: StringName = &""
var _walk_speed := 142.5
var guest := false
var _held := false
var _event := false
var _enabled := true
var _row: Dictionary = {}
var _params: Dictionary = {}
var _home := Vector2.ZERO
var _target := Vector2.ZERO
var _wait := 1.0
var _rng := RandomNumberGenerator.new()
var _interact: Area2D
var _body: CollisionShape2D
var _query := PhysicsShapeQueryParameters2D.new()
var _bubble := ""
var _bubble_label: Label
var _bubble_shown := "-"              # the kind the label shows now ("-" = never drawn): the label is restyled only when it changes
var _bubble_queued := false
var _talk_player: Node
var _screen: Node
var _ui_request: RefCounted
var _talk_origin: Dictionary = {}
var _talk_attachment: RefCounted
var _talk_activity: RefCounted
# Identity of the actor activity, separate from model and UI request authority.
# Trusted roots replace it; an inherited tutorial activity may only retain it.
var _activity: RefCounted = RefCounted.new()
var _act := &"idle"
var _walk_generation := 0
var _event_target := Vector2.ZERO
var _event_speed := 0.0
var _event_walking := false
var _walk_ticket: WalkTicket
var _walk_left := 0.0
var _interaction_reach := 60.0

static func create(params: Dictionary) -> Npc2D:
	var npc := Npc2D.new()
	npc.npc_id = StringName(str(params.get("id", "")))
	npc._row = LuaRuntime.get_npc(str(npc.npc_id)).duplicate(true)
	npc._params = params.duplicate(true)
	npc.dialogue_id = StringName(str(npc._row.get("dialogue", npc.npc_id)))
	npc.display_name_key = str(npc._row.get("name_key", "NPC_" + str(npc.npc_id).to_upper()))
	npc.guest = bool(params.get("guest", false))
	var wander := LuaData.dict(npc._row.get("wander", {}))
	npc.wander_radius = float(wander.get("radius", 0)) * Iso.TILE_W if str(params.get("wander", "")) != "0" else 0.0
	npc._walk_speed = float(wander.get("speed", 0.5)) * 285.0
	return npc

static func create_marker(params: Dictionary, pos: Vector2, _cell: Vector2i, parent_area: IsoArea) -> Node:
	var id := str(params.get("id", ""))
	if bool(LuaRuntime.get_npc(id).get("routine", false)) and bool(Svc.static_call("res://scripts/towns/npc_director.gd", &"controls", [id, parent_area], false)):
		return null
	var npc := create(params)
	npc.area = parent_area
	npc.position = parent_area.objects.to_local(pos)
	return npc

func _ready() -> void:
	add_to_group("npc")
	add_to_group("interactable")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = Iso.LAYER_NPC
	collision_mask = Iso.LAYER_WORLD | Iso.LAYER_PLAYER | Iso.LAYER_GROUND_BLOCK   # the rule next to Iso.MASK_WALKING
	_body = CollisionShape2D.new()
	var shape := ConvexPolygonShape2D.new()
	shape.points = _ellipse(Vector2(14, 8))
	_body.shape = shape
	add_child(_body)
	_query.shape = shape
	_query.exclude = [get_rid()]
	visual = IsoChibiSprite2D.create(str(_params.get("visual", _row.get("visual", "fairy"))))
	visual.name = "Visual"
	visual.scale = Vector2.ONE * float(_row.get("scale", 1.0))
	add_child(visual)
	# WorldRoot2D warms the citizens in view behind the fade; TownDirector stages a mid-visit
	# arrival's sheets on worker threads before it spawns him. A fire-and-forget preload here
	# would leave unused threaded requests alive when citizens leave the area.
	face(str(_params.get("facing", _row.get("facing", "S"))))
	_interact = Area2D.new()
	_interact.name = "InteractArea"
	_interact.collision_layer = Iso.LAYER_INTERACTABLE
	_interact.collision_mask = 0
	var reach := maxf(1, float(_params.get("reach", 60)))
	_interaction_reach = reach
	var interaction_shape := CollisionShape2D.new()
	var interaction_ellipse := ConvexPolygonShape2D.new()
	interaction_ellipse.points = _ellipse(Vector2(reach, reach * Iso.squash()))
	interaction_shape.shape = interaction_ellipse
	_interact.add_child(interaction_shape)
	add_child(_interact)
	_bubble_label = BubbleLabel.new()
	_bubble_label.theme = load("res://assets/ui/theme.tres")
	_bubble_label.theme_type_variation = &"NamePlate"
	_bubble_label.position = Vector2(-16, -142)
	_bubble_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bubble_label)
	_home = global_position
	_target = _home
	_rng.seed = hash(npc_id)
	# every broadcast only QUEUES the bubble: one refresh per frame however many arrive (a load emits one flag_changed per flag; SYS-04);
	# bound methods are disconnected with the node
	EventBus.time_of_day_changed.connect(_clock.unbind(2))
	EventBus.modal_changed.connect(_queue_bubble.unbind(1))
	EventBus.quest_accepted.connect(_queue_bubble.unbind(2))
	EventBus.quest_completed.connect(_queue_bubble.unbind(2))
	EventBus.friend_changed.connect(_queue_bubble.unbind(3))
	EventBus.flag_changed.connect(_queue_bubble.unbind(2))
	_clock()
	Svc.static_call("res://scripts/ghostfam/hook/ghostfam_hook.gd", &"attach", [self])

static func _ellipse(radius: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 12:
		var angle := TAU * i / 12.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func get_interaction_prompt() -> String:
	return tr("DLG_PROMPT_TALK_FMT") % tr(display_name_key) if _enabled else ""

func is_enabled() -> bool:
	return _enabled

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	visible = enabled
	collision_layer = Iso.LAYER_NPC if enabled else 0
	if _interact != null:
		_interact.collision_layer = Iso.LAYER_INTERACTABLE if enabled else 0

func _clock() -> void:
	if str(_params.get("when", "")) == "night":
		set_enabled(TimeManager.is_night())
	_queue_bubble()

func _queue_bubble() -> void:
	if _bubble_queued:
		return
	_bubble_queued = true
	_update_bubble.call_deferred()

func _physics_process(delta: float) -> void:
	if not _enabled or is_talking or (_held and not _event_walking):
		velocity = Vector2.ZERO
		return
	if _event_walking:
		_walk_left -= delta
		var to := Iso.to_ground(_event_target - global_position)
		if to.length() <= maxf(2, _event_speed * delta) or _walk_left <= 0:
			var arrived := to.length() <= maxf(2, _event_speed * delta)
			if arrived:
				global_position = _event_target
			visual.update_motion(Vector2.ZERO)
			_finish_walk(arrived)
			return
		else:
			velocity = Iso.to_screen(to.normalized() * _event_speed)
			move_and_slide()
		visual.update_motion(velocity)
		return
	if driven or _event:
		velocity = Vector2.ZERO
		return
	var radius := wander_radius
	if str(_params.get("wander", "")) == "0":
		radius = 0
	var sleeping := str(_row.get("schedule", "sleep")) == "sleep" and TimeManager.is_night()
	if sleeping:
		_target = _home
	var offset := Iso.to_ground(_target - global_position)
	_wait -= delta
	if offset.length() < 5:
		velocity = Vector2.ZERO
		set_act("sleep" if sleeping else ("hover" if bool(_row.get("hover", false)) else "idle"))
		if not sleeping and radius > 0 and _wait <= 0:
			_wait = _rng.randf_range(1.2, 3.0)
			var angle := _rng.randf() * TAU
			var next := _home + Iso.to_screen(Vector2(cos(angle), sin(angle)) * _rng.randf_range(0, radius))
			if _can_stand(next):
				_target = next
	elif _wait <= 0 or sleeping:
		velocity = Iso.to_screen(offset.normalized() * _walk_speed)
		if not _can_stand(global_position + velocity * delta):
			_target = global_position
			velocity = Vector2.ZERO
		move_and_slide()
		visual.update_motion(velocity)

func _can_stand(point: Vector2) -> bool:
	if area != null:
		if area.walkable_test.is_valid():
			if not bool(area.walkable_test.call(point)):
				return false
		elif not area.is_walkable(area.global_to_cell(point)):
			return false
	_query.transform = Transform2D(0, point)
	_query.collision_mask = collision_mask
	return get_world_2d().direct_space_state.intersect_shape(_query, 1).is_empty()

## Public root; all internal resumes use _interact_owned with the old origin.
func interact(player: Node) -> void:
	if not is_instance_valid(player): return
	var id := PlayerRegistry.registered_id(player)
	if id == &"": return
	_interact_owned(weakref(player), EventBus.interaction_origin(id, self, player))

func _attached(attachment: RefCounted) -> bool:
	return attachment != null and _talk_attachment == attachment and is_talking

func _talk_current(attachment: RefCounted, origin: Dictionary) -> bool:
	return _attached(attachment) and activity_current(_talk_activity) and EventBus.interaction_physical_current(origin, self)

## Resolve weak/Variant arguments BEFORE any typed Node dispatch.
func _interact_owned(player_ref: Variant, origin: Dictionary) -> void:
	var player: Variant = player_ref.get_ref() if player_ref is WeakRef else null
	if is_talking or not _enabled or not is_inside_tree() or GameManager.is_modal_open() or not EventBus.interaction_body_current(origin, self, player): return
	_activity = RefCounted.new()
	var attachment := RefCounted.new()
	var page: Dictionary = PlayerRegistry.for_player(origin.recipient.player_id, func():
		if not bool(Svc.static_call("res://scripts/ghostfam/hook/ghostfam_hook.gd", &"before_talk_owned", [self, player, origin], true)): return {}
		if not EventBus.interaction_body_current(origin, self, player): return {}
		is_talking = true
		_talk_origin = origin
		_talk_attachment = attachment
		_talk_activity = _activity
		_talk_player = player
		_held = true
		if player.has_method("begin_talk"):
			player.begin_talk(global_position)
		if not _talk_current(attachment, origin): return {}
		visual.set_facing_direction(player.global_position - global_position)
		set_act("talk")
		# Build before starts can synchronously complete a quest. Each boundary
		# validates the SAME root; in-callee authored multi-writes are separate.
		var ctx := NpcDialogue.context_owned(str(npc_id), player, origin)
		if not _talk_current(attachment, origin): return {}
		var initial := NpcDialogue.build_owned(str(npc_id), str(dialogue_id), ctx, guest, origin)
		if not _talk_current(attachment, origin): return {}
		NpcDialogue.begin_owned(str(npc_id), initial, origin)
		if not _talk_current(attachment, origin): return {}
		EventBus.publish_dialogue_started(origin, npc_id, dialogue_id, attachment)
		if _talk_current(attachment, origin): EventBus.publish_npc_meeting(origin, self, attachment)
		return initial)
	if not _attached(attachment): return
	if page.is_empty() or not _talk_current(attachment, origin):
		_end_talk(0, false, attachment)
		return
	_present_page(page, origin, attachment)

func _present_page(page: Dictionary, origin: Dictionary, attachment: RefCounted) -> RefCounted:
	if not _talk_current(attachment, origin): return null
	var screen := get_tree().get_first_node_in_group("dialogue_ui")
	if screen == null:
		_end_talk(0, false, attachment)
		return null
	_screen = screen
	var request: RefCounted = screen.create_request()
	_ui_request = request
	_page(page, origin, attachment, screen, request)
	return request

func _page(page: Dictionary, origin: Dictionary, attachment: RefCounted, screen: Node, request: RefCounted) -> void:
	# The completing receipt outlives this optional physical actor. Its static
	# continuation retains only weak bodies/actors and the original profile.
	NpcDialogue.present_owned(self, page, origin, attachment, screen, request)

func _owned_followup(player_ref: Variant, page: Dictionary, origin: Dictionary) -> void:
	var player: Variant = player_ref.get_ref() if player_ref is WeakRef else null
	if not EventBus.interaction_body_current(origin, self, player): return
	_begin_followup(player, page, origin)

## Explicit independent page root when origin is omitted (tutorial/tool API).
## Internal followups always pass their retained origin, never recapture it.
func _begin_followup(player: Variant, page: Dictionary, origin: Dictionary = {}, retained_activity: RefCounted = null) -> RefCounted:
	if retained_activity != null and not activity_current(retained_activity): return null
	if is_talking or not is_inside_tree() or GameManager.is_modal_open() or not is_instance_valid(player): return null
	var id := PlayerRegistry.registered_id(player)
	if id == &"": return null
	if origin.is_empty(): origin = EventBus.interaction_origin(id, self, player)
	if not EventBus.interaction_body_current(origin, self, player): return null
	if retained_activity == null: _activity = RefCounted.new()
	var attachment := RefCounted.new()
	PlayerRegistry.for_player(id, func():
		is_talking = true
		_held = true
		_talk_player = player
		_talk_origin = origin
		_talk_attachment = attachment
		_talk_activity = _activity
		if player.has_method("begin_talk"): player.begin_talk(global_position)
		if not _talk_current(attachment, origin): return
		NpcDialogue.begin_owned(str(npc_id), page, origin)
		if not _talk_current(attachment, origin): return
		EventBus.publish_dialogue_started(origin, npc_id, dialogue_id, attachment)
		if _talk_current(attachment, origin): EventBus.publish_npc_meeting(origin, self, attachment))
	if not _attached(attachment): return null
	if not activity_current(_talk_activity) or not EventBus.interaction_physical_current(origin, self):
		_end_talk(0, false, attachment)
		return null
	return _present_page(page, origin, attachment)

func _end_talk(lines: int, completed: bool, expected: RefCounted = null) -> void:
	if not is_talking or (expected != null and not _attached(expected)): return
	# Detach the exact talk BEFORE any body/social/public callback. Old cleanup
	# must not erase a synchronously installed replacement on this same actor.
	var origin := _talk_origin
	var attachment := _talk_attachment
	var activity := _talk_activity
	var player := _talk_player
	is_talking = false
	if _activity == activity: _held = false
	_talk_player = null
	_talk_origin = {}
	_talk_attachment = null
	_talk_activity = null
	if is_instance_valid(player) and player.has_method("end_talk"): player.end_talk()
	if EventBus.interaction_current(origin):
		PlayerRegistry.for_player(origin.recipient.player_id, func():
			SocialManager.conversation_finished_owned(str(npc_id), lines, completed, origin))
	EventBus.publish_dialogue_ended(origin, attachment)
	if _talk_attachment != null or _activity != activity: return
	set_act("hover" if bool(_row.get("hover", false)) else "idle")
	if is_inside_tree(): _update_bubble()

func handle_choice(action: String, data: Dictionary = {}) -> void:
	NpcDialogue.action(str(npc_id), action, data, guest)

func _exit_tree() -> void:
	_activity = null
	_finish_walk(false)
	if is_talking:
		# Capture the exact request before terminal callbacks can open another.
		var screen := _screen
		var request := _ui_request
		_ui_request = null
		_end_talk(0, false)
		if is_instance_valid(screen) and request != null:
			screen.close_request(request)
	_walk_generation += 1

func set_driven(enabled: bool) -> void:
	driven = enabled and not guest
	routine_id = npc_id if driven else &""
	velocity = Vector2.ZERO

func set_interaction_reach(reach: float) -> void:
	reach = maxf(1, reach)
	if is_equal_approx(reach, _interaction_reach):
		return
	_interaction_reach = reach
	if _interact != null:
		var shape := _interact.get_child(0) as CollisionShape2D
		(shape.shape as ConvexPolygonShape2D).points = _ellipse(Vector2(reach, reach * Iso.squash()))

func activity_current(receipt: RefCounted) -> bool:
	return receipt != null and _activity == receipt and is_inside_tree() and not is_queued_for_deletion()

func hold(held: bool) -> void:
	_activity = RefCounted.new()
	_held = held
	if held:
		velocity = Vector2.ZERO

## Room guests have no town driver. Keep their idle anchor with their assigned
## floor point, including after furniture/guest layout changes.
func set_guest_home(point: Vector2) -> void:
	if not guest:return
	global_position = point
	_home = point
	_target = point
	velocity = Vector2.ZERO
	face("S")

func set_act(act: String) -> void:
	var clip := StringName(act)
	var rendered := clip if visual != null and visual.has_clip(clip) else &"idle"
	if visual != null and (clip != _act or visual.current_clip != rendered):
		_act = clip
		visual.play_loop(rendered)

func face(direction: Variant) -> void:
	if visual == null:
		return
	var index := Iso.DIR8_NAMES.find(str(direction)) if direction is String or direction is StringName else int(direction)
	visual.set_direction_index(clampi(index, 0, 7))

func event_begin(retained_activity: RefCounted = null) -> void:
	if retained_activity != null and not activity_current(retained_activity): return
	if retained_activity == null: _activity = RefCounted.new()
	_event = true
	_bubble = ""
	_held = true
	velocity = Vector2.ZERO
	_update_bubble()

func event_end() -> void:
	_event = false
	_bubble = ""
	_finish_walk(false)
	_walk_generation += 1
	hold(false)
	Svc.static_call("res://scripts/towns/npc_director.gd", &"resync", [str(npc_id)])

## Return a completion signal rather than awaiting on this disposable Node.
## Callers can await it; despawn and cancellation also resolve the ticket.
func event_walk_to(point: Vector2, speed := 100.0, retained_activity: RefCounted = null, current: Callable = Callable()) -> Signal:
	var ticket := WalkTicket.new()
	if retained_activity == null: _activity = RefCounted.new()
	var activity := _activity
	var admitted := (retained_activity == null or activity_current(retained_activity)) and (not current.is_valid() or bool(current.call()))
	if admitted:
		_walk_generation += 1
		var generation := _walk_generation
		_finish_walk(false)
		# Resolving a previous ticket is callback-producing. Never overwrite a
		# newer walk/hold/talk, or renew the tutorial's revoked model origin.
		admitted = _activity == activity and _walk_generation == generation and (not current.is_valid() or bool(current.call()))
	if not admitted:
		# Preserve the public Signal return contract even for refused admission.
		# This resolves only the refused ticket, never retries physical work.
		ticket.finished.emit.call_deferred(false)
		return ticket.finished
	_walk_ticket = ticket
	_event_target = point
	_event_speed = maxf(1, speed)
	_walk_left = Iso.to_ground(point - global_position).length() / _event_speed + 3.0
	_event_walking = true
	return ticket.finished

func _finish_walk(completed: bool) -> void:
	_event_walking = false
	velocity = Vector2.ZERO
	var ticket := _walk_ticket
	_walk_ticket = null
	if ticket != null:
		ticket.finished.emit(completed)

func event_face(direction: Variant) -> void:
	face(direction)

func event_stand(at: Vector2, direction := "S") -> void:
	_finish_walk(false)
	global_position = at
	velocity = Vector2.ZERO
	face(direction)

func event_clip(clip: String) -> void:
	set_act(clip)

func event_emote(kind: String) -> void:
	set_bubble(kind)

func set_bubble(kind: String) -> void:
	_bubble = kind
	_update_bubble()

func _update_bubble() -> void:
	_bubble_queued = false
	if _bubble_label == null:
		return
	var cinematic := GameManager.is_modal_open(&"event")
	var kind := _bubble
	if cinematic:
		if not _event:kind = ""
	elif not guest and not QuestManager.offerable(npc_id).is_empty():
		kind = "quest"
	elif not SocialManager.events_ready(str(npc_id)).is_empty():
		kind = "heart"
	elif SocialManager.is_birthday(str(npc_id)):
		kind = "birthday"
	if kind != _bubble_shown:
		_bubble_shown = kind
		_bubble_label.text = {"quest": "!", "heart": "♥", "note": "♪", "drop": "·"}.get(kind, "")
		_bubble_label.set("candle", kind == "birthday")
		_bubble_label.add_theme_color_override("font_color", C.ROSE if kind == "heart" else C.CHALK)
		_bubble_label.queue_redraw()
	_bubble_label.visible = (_bubble_label.text != "" or kind == "birthday") and not is_talking and not bool(get_meta("ghostfam_hiding",false))
