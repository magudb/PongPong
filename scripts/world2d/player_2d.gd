class_name Player2D
extends PlayerBody2D
## Gameplay controller. The shared body owns collision, camera bounds and cached E queries.
## Combat owns its hit windows; crops and inventory retain their own persistent state.
signal fainted
signal swung(dir_screen: Vector2)
signal dodged
signal light_burst(radius_ground: float)
signal damaged(half_hearts: int)
signal tool_used(item_id: StringName, cell: Vector2i, ok: bool)
signal equipment_display_changed

var hotbar := Hotbar.new()
var max_oil: float = 150.0
var oil: float = 150.0
var oil_draining: bool = false
var lantern: PointLight2D
var ghost_light: PointLight2D
var combat: PlayerCombat2D
var _slow_remaining: float = 0
var _slow_mult: float = 1
var held_equipment: HeldEquipment2D
var outfit_layers: WardrobeLayers
var is_jumping: bool = false
var invulnerable: bool = false
var mouse_aim: bool = false
## Combat keeps the precise ground direction; the painted pose has eight rows.
var combat_aim := Vector2.DOWN
var _farm_use_held := false
var _farm_use_cell := Vector2i.ZERO
var _farm_use_item := &""
## The held use started with a click: its repeats follow the cursor (cursor_cell), not the facing cell.
var _farm_use_mouse := false
## The cursor in viewport coordinates (cursor_global converts it). _input stores every mouse event before the GUI sees it,
## so the position stays current over the HUD and open panels too.
var _cursor_screen := Vector2.ZERO
## The cell the running click works on (a press, a held click's repeat or a buffered click): tool_cell() then returns it.
## null for E, the X key and the pad, which keep the facing cell even while the mouse is the aiming device.
var _click_cell: Variant = null
## The marker's device, kept apart from mouse_aim (combat aim): a real mouse move or a click over the world puts the marker
## on the cursor's cell; a movement key, E, X, a pad input or the pointer leaving the window hands it back to the facing
## cell, so the marker always shows what the next key press works on.
var _marker_pointer := false
## One farm click made while the previous tool use still runs: its cell, fired once the hero is free (review: fast
## click-click-click along a row must work every clicked tile).
var _click_buffer: Variant = null
var _click_buffer_item := &""
var _click_buffer_time := 0.0
## The running tool use came from a click: walking keeps the hero turned toward the clicked cell until the use ends.
var _click_facing := false
## Throttles the "land first" whisper of a tool used in flight.
var _flight_whisper_time := 0.0
## cursor_cell() of a click that works nothing (seeds or a placed object under the feet, an object beyond reach).
const NO_CELL := Vector2i(-99999, -99999)
## A buffered click outlives the running tool use by this long.
const CLICK_BUFFER_S := 0.15
const FLIGHT_WHISPER_S := 2.5
var _marker: TargetMarker2D
var _last_stats: Dictionary = {}
var _stats_timer: float = 0.0
var _exhausted: bool = false
var _regen_delay: float = 0.0
var _tool_time: float = 0.0
var _using_item: StringName = &""
var _display_item: StringName = &""
var _display_context: StringName = &"selected"
var _display_available := false
var _display_drawn := false
var _altitude: float = 0.0
var _vertical_speed: float = 0.0
var _flight_time: float = 0.0
var _climb_up: bool = false
var _climb_down: bool = false
var _landing: bool = false
var _landing_at: Vector2
var _oil_empty_time: float = 0.0
var _oil_low_said: bool = false
var _event_active: bool = false
var _event_generation: int = 0
var _camera_generation := 0
var _camera_tween: Tween
var _camera_zoom_before: float = Iso.DEFAULT_ZOOM
var _bob_time: float = 0.0
var _flower_time: float = 0.0
var _flower_cell := Vector2i(-999, -999)
## The marker's cached placement answer (PlacementService.can_place runs a physics query): per cell and item, refreshed every PROMPT_REFRESH_S.
var _place_cell := Vector2i(-999, -999)
var _place_item := &""
var _place_reason := ""
var _place_stale: float = 0.0
const RULES := "res://scripts/dungeon_run/dungeon_run.gd"
const GEM := "res://scripts/combat/lantern_gem.gd"
const PLACEMENT := "res://scripts/farm/placement_service.gd"

func _ready() -> void:
	if admission_only:
		super._ready()
		hotbar.bind_body(self)
		var row := PlayerRegistry.peek_state(player_id)
		if row != null:
			half_hearts = row.half_hearts
			stamina = row.stamina
			oil = row.oil
			if row.hotbar is Dictionary: hotbar.from_dict(row.hotbar)
		return
	EventBus.modal_changed.connect(func(stack):
		if stack.is_empty() and controls.local_active():
			# A pausing modal stopped _input: take up the pointer where it is now, not where it was when the modal opened.
			_cursor_screen = controls.pointer_position(get_viewport())
		if not stack.is_empty():
			_farm_use_held = false
			_click_buffer = null
			# A pausing modal freezes _physics_process, so its paused branch never runs.
			if combat != null:
				combat.clear_buffer())
	super._ready()
	refresh_stats()
	stamina = max_stamina
	half_hearts = max_half_hearts
	max_oil = float(GameData.combat("oil_seconds", 150))
	oil = max_oil
	lantern = PointLight2D.new()
	lantern.name = "Lantern"
	lantern.texture = Glow.light_texture()
	lantern.position.y = -40.0 * Iso.S
	lantern.enabled = false
	add_child(lantern)
	ghost_light = PointLight2D.new()
	ghost_light.name = "GhostLight"
	ghost_light.texture = Glow.light_texture()
	ghost_light.position.y = -45.0 * Iso.S
	add_child(ghost_light)
	combat = PlayerCombat2D.new()
	combat.name = "Combat"
	add_child(combat)
	combat.setup(self)
	combat.weapon_drawn.connect(func(_item: StringName): _sync_equipment_display())
	hotbar.changed.connect(_emit_hotbar)
	hotbar.bind_body(self)
	hotbar.fill_defaults()
	outfit_layers = WardrobeLayers.new()
	outfit_layers.world_outfit = true
	outfit_layers.owner_body = self
	visual.add_child(outfit_layers)
	held_equipment = HeldEquipment2D.new()
	held_equipment.name = "HeldEquipment"
	add_child(held_equipment)
	EventBus.hotbar_assign_requested.connect(func(id: StringName, slot: int, item_id: StringName) -> void:
		if PlayerRegistry.registered_id(self) == id: hotbar.assign(slot, item_id))
	EventBus.player_inventory_changed.connect(_on_inventory_changed)
	EventBus.outfit_changed.connect(func(id: StringName, _outfit: Dictionary):
		if PlayerRegistry.registered_id(self) == id: refresh_stats())
	EventBus.home_upgraded.connect(func(_old: int, _new: int): refresh_stats())
	EventBus.hygge_changed.connect(func(_score: int, _level: StringName): refresh_stats())
	EventBus.game_event.connect(_on_game_event)
	_emit_stats_on_bus()
	_emit_oil()
	var footsteps := PlayerFootsteps.new()
	footsteps.name = "Footsteps"
	add_child(footsteps)
	# The pointer left the window: its last position is stale, so the marker goes back to the facing cell.
	get_window().mouse_exited.connect(func(): _marker_pointer = false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_marker):
		_marker.queue_free()

func refresh_stats() -> void:
	actor_work(_refresh_owned_stats)

func refresh_stats_owned(receipt: Dictionary, origin: Dictionary) -> void:
	if not _combat_body_current(receipt, origin): return
	PlayerRegistry.for_player(origin.recipient.player_id, func():
		_calculate_stats()
		_emit_stats_on_bus_owned(receipt, origin))

func _refresh_owned_stats() -> void:
	_calculate_stats()
	_emit_stats_on_bus()

func _calculate_stats() -> void:
	_walk = float(GameData.player_cfg("walk_speed", 285)) * (1.0 + Perks.total("speed"))
	_run = float(GameData.player_cfg("run_speed", 450)) * (1.0 + Perks.total("speed"))
	max_stamina = float(GameData.player_cfg("max_stamina", 100)) + Perks.total("energy")
	stamina = minf(stamina, max_stamina)
	max_half_hearts = maxi(1, int(Svc.static_call(RULES, &"hearts_max", [], GameData.combat("max_half_hearts", 10))))
	half_hearts = mini(half_hearts, max_half_hearts)

func _on_character_changed(player_id: StringName, character_id: StringName) -> void:
	if player_id != self.player_id:
		return
	super._on_character_changed(player_id, character_id)
	refresh_stats()

func _on_game_event(event: StringName, _data: Dictionary) -> void:
	if event == &"assist_changed":
		refresh_stats()

func enter_area(target: IsoArea, at: Vector2) -> void:
	_farm_use_held = false
	var world := get_tree().get_first_node_in_group("world_2d")
	if world != null and world.has_method("farm_for_area"):
		farm = world.farm_for_area(target.map.id)
	_event_generation += 1
	_cancel_flight()
	super.enter_area(target, at)
	if combat != null:
		combat.cancel_action()
		if state in [S.USING, S.SWING]:
			state = S.FREE
	_using_item = &""
	_tool_time = 0.0
	_sync_equipment_display()
	if _marker == null or not is_instance_valid(_marker):
		_marker = TargetMarker2D.new()
	if _marker.get_parent() != null:
		_marker.get_parent().remove_child(_marker)
	area.ground_fx.add_child(_marker)
	_marker.projection = area.projection
	_marker.visible = controls.local_active()
	oil_draining = _is_action_area() and area.map.ambient in [&"forest", &"cave"] and int(area.map.extra.get("floor",0)) > 0
	lantern.enabled = _is_action_area() and area.map.ambient in [&"forest", &"cave"]
	_update_lantern()

func world_input_allowed() -> bool:
	return controls.local_active() and PlayerRegistry.registered_id(self) != &"" and area != null and not GameData.gm().is_modal_open() and state not in [S.TALKING, S.FAINTED] and not _event_active and not _world_in_transition()

## A travel, the night or a faint runs behind the black fade (WorldRoot2D.traveling / sleeping): E on a counter would open its screen
## UNDER the fade, where the next keys act on it blind (review GAP1-03). Hotkey screens already refuse then (UiNav.world_is_free).
func _world_in_transition() -> bool:
	var world := get_tree().get_first_node_in_group("world_2d") if is_inside_tree() else null
	return world != null and (bool(world.get("traveling")) or bool(world.get("sleeping")))

## Every mouse event updates the cursor position, wherever it lands. A move over the in-world HUD never reaches
## _unhandled_input (the GUI takes it), yet it still makes the mouse the device in use, so the marker hides over the HUD;
## a move over an open panel or modal changes no device.
func _input(event: InputEvent) -> void:
	if not controls.handle_event(event):
		return
	if event is InputEventMouse:
		_cursor_screen = (event as InputEventMouse).position
	if event is InputEventMouseMotion and not GameData.gm().is_modal_open():
		_track_aim_device(event)

func _unhandled_input(event: InputEvent) -> void:
	if not controls.handle_event(event):
		return
	actor_work(func(): _handle_world_event(event))

## Trusted owner-resolved HUD dispatch shares world guards, not synthetic identity.
func select_gui_slot(index: int) -> void:
	if world_input_allowed():
		actor_work(func(): hotbar.select(index))

func _handle_world_event(event: InputEvent) -> void:
	if event.is_action_released("use_tool"):
		_farm_use_held = false
	_track_aim_device(event)
	if event is InputEventMouse:
		_cursor_screen = (event as InputEventMouse).position
	if not world_input_allowed():
		return
	var chord_slot := controls.hotbar_slot(event)
	if chord_slot >= 0:
		hotbar.select(chord_slot)
		_climb_down = false
		controls.consume_if_handled()
		return
	if event is InputEventJoypadButton and controls.hotbar_modifier():
		controls.consume_if_handled()
		return
	# A press on a HUD panel that only passes the mouse on (a PanelContainer) still reaches here: it is not a click on the ground.
	if event is InputEventMouseButton and event.pressed and not _is_wheel(event as InputEventMouseButton) and _cursor_over_gui():
		return
	if event.is_action_released("attack"):
		combat.attack_held = false
	if event.is_action_released("jump"):
		_climb_up = false
	if event.is_action_released("fly_descend"):
		_climb_down = false
	if is_flying and event.is_action_pressed("jump"):
		_climb_up = true
		return
	if is_flying and event.is_action_pressed("fly_descend"):
		_climb_down = true
		return
	if event.is_action_pressed(&"hotbar_previous") or event.is_action_pressed(&"hotbar_next"):
		hotbar.cycle(-1 if event.is_action_pressed(&"hotbar_previous") else 1)
		controls.consume_if_handled()
		return
	for index in 10:
		if event.is_action_pressed("slot_%d" % (index + 1)):
			hotbar.select(index) # 9/0 remain defined inputs; this eight-slot layout ignores them.
			controls.consume_if_handled()
			return
	if _zoom_input(event):
		controls.consume_if_handled()
		return
	if _is_action_area():
		# attack and use_tool share every binding: in an action area the press is an attack through the
		# buffer (and Cozy auto-swing), unless the selected tool has something to mine or chop in front (DUN-07).
		if event.is_action_pressed("attack") or event.is_action_pressed("use_tool"):
			# A click works the clicked cell: a tree or rock there that takes the tool is hit, anything else is a swing
			# toward the clicked ground point (aimed at the press position, not wherever the cursor is when a buffer fires).
			var click := event is InputEventMouseButton
			_click_cell = cursor_cell(hotbar.current()) if click else null
			if _tool_target_in_front():
				use_selected()
			else:
				combat.request(&"slash", &"", cursor_global() if click else null)
			_click_cell = null
		elif event.is_action_pressed("dodge"):
			combat.request(&"dodge")
		elif event.is_action_pressed("light"):
			fairy_light()
		elif event.is_action_pressed("drink"):
			drink()
		elif event.is_action_pressed("interact"):
			try_interact()
		elif event.is_action_pressed("fly_toggle"):
			toggle_flight()
	elif event.is_action_pressed("interact"):
		# Pad A is interact and jump: with nothing to talk to or use it hops (GAP3-11). A target that refuses
		# (a ripe crop with a full bag) is not "nothing", so it does not hop.
		if not try_interact() and event.is_action_pressed("jump") and not _interaction_target_in_front():
			hop()
	elif event.is_action_pressed("fly_toggle"):
		toggle_flight()
	elif event.is_action_pressed("use_tool"):
		_farm_use_mouse = event is InputEventMouseButton
		_click_cell = cursor_cell(hotbar.current()) if _farm_use_mouse else null
		_farm_use_held = _farm_repeat_allowed()
		_farm_use_item = hotbar.current()
		if state == S.USING:
			# The previous use still runs: a click waits for it (one buffered cell), and a held press repeats as soon as
			# the hero is free (NO_CELL never equals a worked cell, so the repeat in _physics_process fires).
			if _farm_use_mouse and _click_bufferable():
				_click_buffer = _click_cell
				_click_buffer_item = hotbar.current()
				_click_buffer_time = _tool_time + CLICK_BUFFER_S
			_farm_use_cell = NO_CELL
		else:
			_farm_use_cell = tool_cell()
			use_selected()
		_click_cell = null
	elif event.is_action_pressed("jump"):
		hop()
	for action in ["interact", "fly_toggle", "attack", "dodge", "light", "drink", "jump", "use_tool"]:
		if event.is_action_pressed(action):
			controls.consume_if_handled()
			break

## Swings aim at the cursor only while the mouse is the device in use: a real mouse move or a click picks it,
## a pad input or a keyboard attack hands the aim back to the walking direction (GAP3-05).
## The marker follows the same devices, and a movement key or E also hands it back to the facing cell (combat aim keeps
## the mouse then: walking with the keys while aiming with the mouse is normal play), until the mouse moves again.
func _track_aim_device(event: InputEvent) -> void:
	if (event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() >= UiNavWatcher.MOUSE_MOVE_MIN) or (event is InputEventMouseButton and event.pressed):
		mouse_aim = true
		_marker_pointer = true
	elif (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) >= UiNavWatcher.STICK_THRESHOLD) \
			or (event is InputEventKey and event.pressed and event.is_action("attack")):
		mouse_aim = false
		_marker_pointer = false
	elif event is InputEventKey and event.pressed and not event.is_echo():
		for action in [&"interact", &"use_tool", &"move_forward", &"move_back", &"move_left", &"move_right"]:
			if event.is_action(action):
				_marker_pointer = false
				break

## The selected hotbar tool (pickaxe, axe) and a host in reach that takes it (_takes_tool) are there, so an action-area
## press mines instead of swinging. A consumable or a weapon in the slot never takes the press (DUN-07), and neither does
## a host that takes another tool: an axe beside a rock still attacks.
func _tool_target_in_front() -> bool:
	var item := hotbar.current()
	var def := GameData.item_def(item)
	var tool := str(def.get("tool_type", ""))
	if str(def.get("category", "")) != "tool" or tool == "" or not GameData.eco().has_item(item):
		return false
	var takes := func(h: Node) -> bool: return _takes_tool(h, tool)
	if _click_cell != null:
		return _click_cell != NO_CELL and _host_at(_click_cell, takes) != null
	return nearest_interactable(takes) != null

# ------------------------------------------------------------------ mouse targeting (owner request 2026-10-20)

## The cursor's point on the ground, in the global coordinates of the area. The canvas transform of this frame holds the
## camera (its zoom and smoothing); event positions are already in viewport coordinates (canvas_items stretch, Retina).
func cursor_global() -> Vector2:
	return controls.aim_position(self)

## The cell a click works on: the ground cell under the cursor when it is one of the nine cells around the feet (the feet's
## own cell only for what can be done standing on it, _feet_cell_ok), else the neighbour cell toward the cursor. NO_CELL
## when the click works nothing: seeds or a placed object under the feet, a placed object beyond reach (a click anywhere on
## the screen must never spend a sprinkler or a chest on a cell the player did not point at).
func cursor_cell(item: StringName) -> Vector2i:
	var feet := area.global_to_cell(global_position)
	var at := cursor_global()
	var cell := area.global_to_cell(at)
	var d := cell - feet
	if absi(d.x) > 1 or absi(d.y) > 1:
		if _places_object(item):
			return NO_CELL
		# The eight neighbours lie on the 45-degree rays in GROUND space (iso exactly, ortho within half a degree).
		return feet + area.facing_step(Iso.dir8_of(Iso.to_ground(at - global_position)))
	if d == Vector2i.ZERO and not _feet_cell_ok(item, cell):
		return NO_CELL
	return cell

## Seeds and placed objects never go under the hero's own feet. Watering, tilling, fertilising, a ripe crop and a tool on
## an overlapping tree or rock are fine on the cell the hero stands on.
func _feet_cell_ok(item: StringName, cell: Vector2i) -> bool:
	if str(GameData.item_def(item).get("category", "")) != "seed" and not _places_object(item):
		return true
	return _at_farm() and farm.state_of(cell) == FarmGrid.State.READY

static func _places_object(item: StringName) -> bool:
	return str(GameData.item_def(item).get("placeable", "")) == "farm"

## The cell the selected item works on: the clicked cell during a click, else the facing cell (keys, pad, E).
func tool_cell() -> Vector2i:
	return _click_cell if _click_cell != null else target_cell()

## The marker shows the cursor's cell while the mouse is the marker's device, and during a held click (whose repeats
## follow the cursor even while a movement key is down); otherwise the facing cell that E, X and the pad work on.
func _marker_on_cursor() -> bool:
	return _marker_pointer or (_farm_use_held and _farm_use_mouse)

## The marked cell: what the next click works on, or, for a click that would work nothing, the cell under the cursor.
func marker_cell() -> Vector2i:
	if not _marker_on_cursor():
		return target_cell()
	var cell := cursor_cell(hotbar.current())
	return cell if cell != NO_CELL else area.global_to_cell(cursor_global())

## A farm click made during a running use waits for it: tools, seeds, supplies and placed objects (a weapon has its own buffer).
func _click_bufferable() -> bool:
	var def := GameData.item_def(hotbar.current())
	return _at_farm() and (str(def.get("category", "")) in ["tool", "seed", "farm"] or _places_object(hotbar.current()))

## A GUI control (one that does not ignore the mouse) is under the cursor: no marker, and a press there is not a world click.
func _cursor_over_gui() -> bool:
	return get_viewport().gui_get_hovered_control() != null

static func _is_wheel(event: InputEventMouseButton) -> bool:
	return event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]

## Turns the hero to a neighbour cell (the facing cell becomes that cell); the feet's own cell keeps the facing.
func _face_cell(cell: Vector2i) -> void:
	var feet := area.global_to_cell(global_position)
	for index in 8:
		if area.facing_step(index) == cell - feet:
			facing8 = index
			facing_vec = Iso.dir8_vector(index)
			combat_aim = Iso.to_ground(area.cell_to_global(cell) - area.cell_to_global(feet)).normalized()
			visual.set_facing_direction(facing_vec)
			return

## The host on (or overlapping) `cell` that `accept` takes: the hosts whose area meets an interaction circle at the cell
## centre, live before spent, then the nearest to the hero. A click names its cell, so no other host in reach stands in.
func _host_at(cell: Vector2i, accept: Callable) -> Node:
	if state != S.FREE or area == null:
		return null
	_ensure_interact_query()
	var hosts: Array[Node2D] = []
	_query_hosts(area.cell_to_global(cell), hosts, "")
	var best: Node2D = null
	var best_rank := Vector2.INF
	for host in hosts:
		if not bool(accept.call(host)):
			continue
		var spent: bool = host.has_method("is_spent") and bool(host.call("is_spent"))
		var rank := Vector2(1.0 if spent else 0.0, Iso.ground_dist(host.global_position, global_position))
		if rank < best_rank:
			best = host
			best_rank = rank
	return best

## Something E could act on is in front: an interactable host or a ripe crop.
func _interaction_target_in_front() -> bool:
	return nearest_interactable() != null or (_at_farm() and farm.state_of(target_cell()) == FarmGrid.State.READY)

func _is_action_area() -> bool:
	return area != null and area.projection == &"ortho"

func set_zoom(value: float) -> void:
	if area != null:
		_set_zoom(value)

func _physics_process(delta: float) -> void:
	# Remote samples are passive until MP5/6 supplies host validation/replication.
	if not controls.local_active():
		_input_revoked()
		return
	actor_work(func(): _tick_owned(delta))

func _input_revoked() -> void:
	super._input_revoked()
	_farm_use_held = false
	_click_buffer = null
	_climb_up = false
	_climb_down = false
	_marker_pointer = false
	mouse_aim = false
	if combat != null:
		combat.clear_buffer()
		combat.attack_held = false
	if is_instance_valid(_marker):
		_marker.hide()

func _tick_owned(delta: float) -> void:
	if area == null or combat == null:
		return
	if not controls.is_action_pressed(&"use_tool"):
		_farm_use_held = false
	if not controls.is_action_pressed(&"attack"):
		combat.attack_held = false
	if is_flying:
		_climb_up = controls.is_action_pressed(&"jump")
		_climb_down = controls.is_action_pressed(&"fly_descend")
	_sync_equipment_display()
	var paused: bool = GameData.gm().is_modal_open() or state in [S.TALKING, S.FAINTED] or _event_active
	if paused:
		_farm_use_held = false
		_click_buffer = null
		combat.attack_held = false
		combat.clear_buffer()
		_climb_up = false
		_climb_down = false
		velocity = Vector2.ZERO
		_gvel = Vector2.ZERO
		_update_prompt(delta)
		return
	combat.tick(delta)
	_zoom_stick(delta)
	if combat.hit_stop > 0 or combat.stopped_this_tick:
		return
	_tool_time = maxf(0.0, _tool_time - delta)
	_click_buffer_time = maxf(0.0, _click_buffer_time - delta)
	_flight_whisper_time = maxf(0.0, _flight_whisper_time - delta)
	_regen_delay = maxf(0.0, _regen_delay - delta)
	if state == S.USING and _tool_time == 0.0:
		state = S.FREE
		_using_item = &""
	_sync_equipment_display()
	var direction := controls.move_vector()
	var running := false
	if _exhausted and stamina >= max_stamina * float(GameData.player_cfg("run_recover_ratio", 0.2)):
		_exhausted = false
	if state == S.FREE and not is_flying and not _landing and direction != Vector2.ZERO and controls.is_action_pressed(&"run") and not _exhausted:
		running = true
		_spend_stamina(float(GameData.player_cfg("run_cost_per_second", 15)) * float(GameData.perk("run_cost_mult", 1.0)) * delta)
		if stamina <= 0:
			_exhausted = true
	if not running and not is_flying and _regen_delay == 0.0 and state == S.FREE:
		stamina = minf(max_stamina, stamina + float(GameData.player_cfg("stamina_regen_per_second", 12)) * delta)
	var speed := _run if running else _walk
	if is_flying:
		speed = _run * 0.9
	elif state in [S.SWING, S.USING]:
		speed *= 0.35
	_slow_remaining = maxf(0,_slow_remaining-delta)
	if _slow_remaining == 0: _slow_mult = 1
	speed *= _slow_mult
	if _landing:
		direction = Iso.to_ground(_landing_at - global_position).normalized()
		speed = minf(_walk, Iso.ground_dist(global_position, _landing_at) / maxf(delta, 0.001))
	_gvel = _gvel.move_toward(direction * speed, (_accel if direction != Vector2.ZERO else _decel) * delta)
	_gvel = combat.movement(_gvel, delta)
	velocity = Iso.to_screen(_gvel)
	move_and_slide()
	_gvel = Iso.to_ground(velocity)
	# A clicked use keeps the hero turned toward the clicked cell while it runs, even when walking the other way.
	if direction != Vector2.ZERO and state != S.DODGE and not (state == S.USING and _click_facing):
		combat_aim = direction.normalized()
		facing8 = Iso.dir8_of(direction)
		facing_vec = Iso.dir8_vector(facing8)
	_update_vertical(delta)
	if forced_clip != &"":
		visual.play_loop(forced_clip)
	else:
		visual.update_motion(velocity, running, is_jumping or _landing, is_flying, direction)
	_update_target(delta)
	if _click_buffer != null and (_click_buffer_time == 0.0 or hotbar.current() != _click_buffer_item or not _at_farm()):
		_click_buffer = null
	if _click_buffer != null and state == S.FREE:
		# The click made during the previous use works its own cell now, if the hero has not walked out of reach of it.
		var buffered: Vector2i = _click_buffer
		var d: Vector2i = buffered - area.global_to_cell(global_position)
		_click_buffer = null
		if buffered != NO_CELL and absi(d.x) <= 1 and absi(d.y) <= 1:
			_click_cell = buffered
			_farm_use_cell = buffered
			_farm_use_item = hotbar.current()
			use_selected()
			_click_cell = null
	if _farm_use_held and _farm_repeat_allowed() and controls.is_action_pressed(&"use_tool") and state == S.FREE:
		# A held click repeats on the cells the cursor moves over (never while it rests on the HUD).
		_click_cell = cursor_cell(hotbar.current()) if _farm_use_mouse and mouse_aim else null
		var cell := tool_cell()
		if (cell != _farm_use_cell or hotbar.current() != _farm_use_item) and not (_click_cell != null and _cursor_over_gui()):
			_farm_use_cell = cell
			_farm_use_item = hotbar.current()
			use_selected()
		_click_cell = null
	_update_prompt(delta)
	_update_oil(delta)
	_update_ghost(delta)
	_stats_timer += delta
	if _stats_timer >= 0.1:
		_stats_timer = 0.0
		_emit_stats_on_bus()

func _update_target(delta: float = 0.0) -> void:
	_flower_time = maxf(0.0, _flower_time - delta)
	_place_stale += delta
	var marked := marker_cell()
	var on_cursor := _marker_on_cursor()
	_marker.global_position = area.cell_to_global(marked)
	_marker.valid = _at_farm() and not (on_cursor and cursor_cell(hotbar.current()) == NO_CELL) and _target_valid(marked)
	_marker.visible = _at_farm() and state == S.FREE and not is_flying and not (on_cursor and _cursor_over_gui())
	if bool(GameData.perk("talks_to_flowers", false)) and _at_farm():
		var current := area.global_to_cell(global_position)
		if current != _flower_cell and _flower_time == 0.0:
			_flower_cell = current
			for cell in farm.plots:
				if Vector2(cell - current).length() <= 2.0 and farm.get_plot(cell).crop_id != &"":
					_flower_time = 10.0
					EventBus.whisper_requested.emit("WHISPER_FLOWER_%d" % (posmod(cell.x + cell.y, 6) + 1))
					break

## The gold ring: the held farm placeable can stand on the cell (the same answer place() gives), else the cell can be tilled.
func _target_valid(cell: Vector2i) -> bool:
	var item := hotbar.current()
	if str(GameData.item_def(item).get("placeable", "")) != "farm":
		return farm.can_till(cell)
	if cell != _place_cell or item != _place_item or _place_stale >= PROMPT_REFRESH_S:
		_place_cell = cell
		_place_item = item
		_place_stale = 0.0
		_place_reason = str(Svc.static_call(PLACEMENT, &"can_place", [item, cell], "WHISPER_NOT_YET"))
	return _place_reason == ""

func _farm_repeat_allowed() -> bool:
	var def := GameData.item_def(hotbar.current())
	return _at_farm() and (str(def.get("category", "")) in ["seed", "farm"] or str(def.get("tool_type", "")) in ["hoe", "watering", "scythe"])

func _at_farm() -> bool:
	return farm != null and area != null and farm.map != null and area.map.id == farm.map.id

func can_interact_now() -> bool:
	return state == S.FREE and not is_flying

func interaction_text(it: Node) -> String:
	if can_interact_now() and _at_farm() and farm.state_of(target_cell()) == FarmGrid.State.READY:
		var crop: StringName = farm.get_plot(target_cell()).crop_id
		return tr("FARMSITE_HARVEST_FMT") % tr(str(GameData.item_def(crop).get("name_key", "")))
	return super.interaction_text(it)

func try_interact() -> bool:
	return bool(actor_work(_try_owned_interact, false))

func _try_owned_interact() -> bool:
	if not world_input_allowed() or not can_interact_now():
		return false
	if _at_farm() and farm.state_of(target_cell()) == FarmGrid.State.READY:
		return farm.harvest(target_cell()) > 0
	return super.try_interact()

func use_selected() -> bool:
	return bool(actor_work(_use_owned_selected, false))

func _use_owned_selected() -> bool:
	if is_flying and world_input_allowed() and hotbar.current() != &"":
		# Tools stay refused in flight, with a word why (a click, X and the pad alike), at most every FLIGHT_WHISPER_S.
		if _flight_whisper_time == 0.0:
			_flight_whisper_time = FLIGHT_WHISPER_S
			EventBus.whisper_requested.emit("FARM_LAND_FIRST")
		return false
	if not world_input_allowed() or state != S.FREE or is_flying:
		return false
	var item := hotbar.current()
	var def := GameData.item_def(item)
	if _click_cell != null:
		if _click_cell == NO_CELL:
			return false
		var clicked: Vector2i = _click_cell
		_face_cell(clicked)
		# A click on a ripe crop picks it, as E does (the axe, pickaxe and scythe keep their own crop rules).
		if _at_farm() and farm.state_of(clicked) == FarmGrid.State.READY and str(def.get("tool_type", "")) not in ["axe", "pickaxe", "scythe"]:
			return farm.harvest(clicked) > 0
	if item == &"" or not GameData.eco().has_item(item):
		return false
	if str(def.get("placeable", "")) == "home":
		EventBus.whisper_requested.emit("INDRET_ONLY_HOME")
		return false
	if str(def.get("tool_type", "")) in ["fishing", "fishing_rod"]:
		EventBus.whisper_requested.emit("WHISPER_FISHING_CLOSED")
		return false
	var cost := float(def.get("stamina_cost", 4.0)) * float(SpeciesPerks.current("tool_cost_mult", 1.0))
	if stamina < cost:
		EventBus.whisper_requested.emit("UI_TIRED")
		return false
	var cell := tool_cell()
	var ok := false
	match str(def.get("category", "")):
		"tool":
			match str(def.get("tool_type", "")):
				"pail":
					# The nearest COW in reach: a hen standing closer must not hide it. A click milks the cow on the clicked cell.
					var cow := (_host_at(cell, _is_cow) if _click_cell != null else nearest_interactable(_is_cow)) as Animal2D
					if cow != null:
						ok = int(Svc.node("AnimalHusbandry").collect_product(cow.animal_id)) > 0
					else:
						EventBus.whisper_requested.emit("UI_TOOL_NO_EFFECT")
				"hoe":
					if _at_farm():
						if str(Svc.static_call("res://scripts/farm/steading/objects/farm_reserve.gd", &"blocked", [area, cell], "")) not in ["", "field", "zone"]:
							EventBus.whisper_requested.emit("FARM_CELL_RESERVED")
						else:
							ok = farm.till(cell)
				"watering":
					ok = _at_farm() and farm.water(cell)
				"scythe":
					if _at_farm():
						for direction in [posmod(facing8 - 1, 8), facing8, posmod(facing8 + 1, 8)]:
							var harvest_cell := area.global_to_cell(global_position) + area.facing_step(direction)
							ok = farm.harvest(harvest_cell) > 0 or farm.clear_crop(harvest_cell) or ok
				"axe", "pickaxe":
					# What the swing acts on: (1) an object on the target cell that takes this tool (a tree for the axe, a rock for
					# the pickaxe, a sprinkler for either), (2) a crop on the target cell, which the tool deliberately removes,
					# (3) another object in reach that takes this tool. A nearer host that does not take it never blocks the swing.
					# A click looks only at the clicked cell.
					var tool := str(def.tool_type)
					var crop: bool = _at_farm() and farm.get_plot(cell) != null and farm.get_plot(cell).crop_id != &""
					var takes := func(h: Node) -> bool: return _takes_tool(h, tool)
					var host: Node = _host_at(cell, takes) if _click_cell != null else nearest_interactable(func(h: Node) -> bool: return area.global_to_cell((h as Node2D).global_position) == cell and _takes_tool(h, tool))
					if host == null and not crop and _click_cell == null:
						host = nearest_interactable(takes)
					if host != null:
						ok = bool(host.call("tool_hit", tool, int(def.get("power", 1)), self))
					elif crop:
						ok = _remove_crop(cell)
					else:
						# Nothing takes this tool: the nearest object that takes another one names it (FOREST_TOOL_PICKAXE on a rock).
						var hittable := func(h: Node) -> bool: return h.has_method("tool_hit")
						var other: Node = _host_at(cell, hittable) if _click_cell != null else nearest_interactable(hittable)
						if other != null:
							other.call("tool_hit", tool, int(def.get("power", 1)), self)
						else:
							EventBus.whisper_requested.emit("UI_TOOL_NO_EFFECT")
		"seed":
			if _at_farm():
				var reason: String = farm.plant(cell, item)
				ok = reason == ""
				if not ok:
					EventBus.whisper_requested.emit(reason)
		"farm":
			ok = _at_farm() and farm.apply_supply(cell, item)
		"consumable", "food":
			ok = GameData.eco().use_item(item)
		"weapon":
			# The same path as the attack action: the input buffer and Cozy auto-swing apply (DUN-07).
			combat.request(&"slash", item, cursor_global() if _click_cell != null else null)
			return state == S.SWING
		_:
			if str(def.get("placeable", "")) == "farm":
				var reason := str(Svc.static_call(PLACEMENT, &"can_place", [item, cell], "WHISPER_NOT_YET"))
				ok = reason == "" and bool(Svc.static_call(PLACEMENT, &"place", [item, cell], false))
				_place_stale = PROMPT_REFRESH_S
				if not ok:
					EventBus.whisper_requested.emit(reason if reason != "" else "WHISPER_NOT_YET")
	if ok:
		_spend_stamina(cost)
		state = S.USING
		_using_item = item
		_click_facing = _click_cell != null
		_sync_equipment_display()
		var dig := maxf(0.1, float(SpeciesPerks.current("dig_speed", 1.0)))
		_tool_time = float(GameData.player_cfg("tool_seconds", 0.34)) / dig
		visual.play_action(&"interact", 1.4 * dig)
	tool_used.emit(item, cell, ok)
	return ok

## An axe / pickaxe on a crop: a ripe one is harvested first (a full backpack keeps it in the ground), the rest is cleared to tilled soil.
func _remove_crop(cell: Vector2i) -> bool:
	var harvested := false
	if farm.state_of(cell) == FarmGrid.State.READY:
		harvested = farm.harvest(cell) > 0
		if not harvested:
			return false
	var cleared: bool = farm.clear_crop(cell, false)
	if cleared:
		EventBus.whisper_requested.emit("FARM_CROP_CLEARED")
	return harvested or cleared

## The tool contract: a host with tool_hit takes a hit from `tool` unless its optional accepts_tool(tool) says no
## (ResourceNode2D: the axe takes trees, the pickaxe rocks, forage takes neither; FarmMachine2D: both).
func _takes_tool(host: Node, tool: String) -> bool:
	return host.has_method("tool_hit") and (not host.has_method("accepts_tool") or bool(host.call("accepts_tool", tool)))

func _is_cow(host: Node) -> bool:
	if not host is Animal2D:
		return false
	var data: Variant = Svc.node("AnimalHusbandry").get_animal((host as Animal2D).animal_id)
	return data != null and str(data.species) == "cow"

func _spend_stamina(amount: float) -> void:
	stamina = maxf(0.0, stamina - maxf(0.0, amount))
	_regen_delay = float(GameData.player_cfg("stamina_regen_delay", 1.0))

func _emit_stats_on_bus() -> void:
	if PlayerRegistry.registered_id(self) == &"":
		return
	var values := {"half_hearts": half_hearts, "max_half_hearts": max_half_hearts, "stamina": stamina, "max_stamina": max_stamina}
	if values == _last_stats:
		return
	if _last_stats.get("half_hearts", -1) != half_hearts or _last_stats.get("max_half_hearts", -1) != max_half_hearts:
		EventBus.player_health_changed.emit(player_id, half_hearts, max_half_hearts)
	_last_stats = values.duplicate()
	stats_changed.emit()
	EventBus.player_stats_changed.emit(player_id, values)

func _emit_stats_on_bus_owned(receipt: Dictionary, origin: Dictionary) -> void:
	if not _combat_body_current(receipt, origin): return
	var values := {"half_hearts": half_hearts, "max_half_hearts": max_half_hearts, "stamina": stamina, "max_stamina": max_stamina}
	if values == _last_stats: return
	var id: StringName = origin.recipient.player_id
	if _last_stats.get("half_hearts", -1) != half_hearts or _last_stats.get("max_half_hearts", -1) != max_half_hearts:
		EventBus.player_health_changed.emit(id, half_hearts, max_half_hearts)
		if not _combat_body_current(receipt, origin): return
	_last_stats = values.duplicate()
	stats_changed.emit()
	if not _combat_body_current(receipt, origin): return
	EventBus.player_stats_changed.emit(id, values)

## One readout for the HUD and the fitted item presenter. An action keeps its
## actual source item until completion even if the hotbar or equipment changes.
func equipment_display() -> Dictionary:
	_sync_equipment_display()
	return {"id": _display_item, "context": _display_context, "available": _display_available, "drawn": _display_drawn}

func _sync_equipment_display() -> void:
	actor_work(_sync_owned_equipment_display)

func _sync_owned_equipment_display() -> void:
	var item := hotbar.current()
	var context: StringName = &"selected"
	if combat != null and state == S.SWING:
		item = combat.active_weapon_id()
		context = &"using"
	elif state == S.USING:
		item = _using_item
		context = &"using"
	elif _is_action_area():
		item = GameData.eco().equipped_item(&"weapon")
		context = &"weapon"
	var available: bool = item != &"" and GameData.eco().has_item(item)
	# A consumed last seed/tonic still names the completed action; it is never
	# mistaken for another item just because inventory changed in that action.
	if context == &"using" and item != &"":
		available = true
	var drawn := available and str(GameData.item_def(item).get("category", "")) in ["tool", "weapon"] and state not in [S.TALKING, S.FAINTED] and forced_clip != &"sleep"
	if item == _display_item and context == _display_context and available == _display_available and drawn == _display_drawn:
		return
	_display_item = item
	_display_context = context
	_display_available = available
	_display_drawn = drawn
	equipment_display_changed.emit()

func _emit_hotbar() -> void:
	if PlayerRegistry.registered_id(self) == &"":
		return
	_sync_equipment_display()
	EventBus.hotbar_changed.emit(player_id, hotbar.entries(), hotbar.selected)

func _on_inventory_changed(id: StringName, _items: Dictionary) -> void:
	if PlayerRegistry.registered_id(self) == id:
		_emit_hotbar()

func heal_half(amount: int) -> void:
	half_hearts = clampi(half_hearts + maxi(0, amount), 0, max_half_hearts)
	_emit_stats_on_bus()

func apply_slow(multiplier: float, seconds: float) -> void:
	_slow_mult = minf(_slow_mult,clampf(multiplier,.1,1))
	_slow_remaining = maxf(_slow_remaining,seconds)

func heal_full() -> void:
	heal_half(max_half_hearts)

func restore_stamina(amount: float) -> void:
	stamina = clampf(stamina + maxf(0.0, amount), 0.0, max_stamina)
	_emit_stats_on_bus()

func add_oil(seconds: float) -> void:
	var before := oil
	oil = clampf(oil + maxf(0.0, seconds), 0.0, max_oil)
	if DungeonFloors.inst() == null or not DungeonFloors.inst().active: _oil_low_said = false
	_oil_empty_time = 0.0
	_update_lantern()
	if oil != before:
		_emit_oil()

func restore_oil() -> void:
	add_oil(max_oil)

func _emit_oil() -> void:
	var id := PlayerRegistry.registered_id(self)
	if id != &"":
		EventBus.player_oil_changed.emit(id, oil, max_oil)

func begin_dungeon_run() -> void:
	_oil_low_said = false
	_oil_empty_time = 0
	combat.begin_run()

func apply_consumable(health: int, oil_seconds: float, energy: float) -> void:
	# The inventory owner already removed the item. Commit every stat before publishing any one of them.
	half_hearts = mini(max_half_hearts, half_hearts + maxi(0, health))
	stamina = minf(max_stamina, stamina + maxf(0.0, energy))
	var before := oil
	oil = minf(max_oil, oil + maxf(0.0, oil_seconds))
	_oil_low_said = false
	_update_lantern()
	_emit_stats_on_bus()
	if before != oil:
		_emit_oil()

func restore_after_sleep() -> void:
	refresh_stats()
	half_hearts = max_half_hearts
	stamina = max_stamina
	_exhausted = false
	_regen_delay = 0.0
	restore_oil()
	_emit_stats_on_bus()

func revive(at: Vector2) -> void:
	global_position = at
	state = S.FREE
	forced_clip = &""
	_cancel_flight()
	combat.reset()
	visual.cancel_action()
	restore_after_sleep()

func _update_oil(delta: float) -> void:
	if not controls.local_active() or not oil_draining:
		return
	# The oil rules are called directly: their old late-binding fallbacks re-implemented them differently (they ignored
	# the auto-refuel and oil assists, review QUAL-11).
	var owned := {"lantern_oil": GameData.eco().count_item(&"lantern_oil"), "lysdraabe": GameData.eco().count_item(&"lysdraabe")}
	var refill := DungeonOilRules.auto_refuel_item(oil, owned)
	if refill != &"":
		GameData.eco().use_item(refill)
	var before := oil
	var gem := _gem_effects()
	var context := {"paused": false, "on_floor": oil_draining, "race_mult": float(GameData.perk("oil_use_mult", 1.0)), "gem_mult": float(gem.get("oil_mult", 1.0)), "assist_oil": _assist_oil()}
	oil = clampf(DungeonOilRules.step(oil, delta, context), 0.0, max_oil)
	if int(before) != int(oil):
		_emit_oil()
	if oil / max_oil < float(GameData.combat("oil_whisper_ratio", 0.2)) and not _oil_low_said:
		_oil_low_said = true
		EventBus.whisper_requested.emit("WHISPER_OIL_LOW")
	if oil == 0.0:
		_oil_empty_time += delta
		if DungeonOilRules.bite_due(oil, half_hearts, _oil_empty_time):
			_oil_empty_time = 0.0
			if half_hearts > 2:
				take_damage(1, global_position)
	_update_lantern()

func _assist_oil() -> Variant:
	return DungeonRun.assist("assist_oil")

func _gem_effects() -> Dictionary:
	var equipped: Variant = Svc.static_call(GEM, &"equipped", [], "")
	return GameData.dict_of(Svc.static_call(GEM, &"effects", [equipped], {}))

func _update_lantern() -> void:
	if lantern == null:
		return
	var ratio := DungeonOilRules.light_ratio(oil)
	var gem := _gem_effects()
	lantern.texture_scale = 630.0 / 128.0 * ratio * float(GameData.perk("dark_light_mult", 1.0)) * float(gem.get("radius_mult", 1.0))
	lantern.color = Color.from_string(str(gem.get("tint", GameData.cfg("forest_look.lantern.color", "ffe9a8"))), Color("ffe9a8"))
	lantern.energy = float(GameData.cfg("forest_look.lantern.energy", 0.10))

func _update_ghost(delta: float) -> void:
	_bob_time += delta
	var bob := sin(_bob_time * TAU * 0.55) * float(GameData.perk("float_bob_px", 0.0))
	visual.set_altitude(_altitude + bob + combat.extra_altitude)
	var night := area.night_factor if area != null else 0.0
	ghost_light.energy = float(GameData.perk("glow_energy_dark" if oil_draining else "glow_energy", 0.0)) * (1.0 if oil_draining else night)
	ghost_light.texture_scale = float(GameData.perk("glow_scale", 0.0))
	ghost_light.color = Color.from_string(str(GameData.perk("glow_color", "bfe0ff")), Color("bfe0ff"))
	ghost_light.enabled = ghost_light.energy > 0.0

func can_fly_here() -> bool:
	return bool(actor_work(func(): return area != null and area.map.flight_allowed and bool(GameData.perk("can_fly", false)), false))

func hop() -> bool:
	if state != S.FREE or is_flying or is_jumping or _landing:
		return false
	is_jumping = true
	_vertical_speed = float(GameData.player_cfg("hop_impulse", 620))
	visual.play_action(&"jump")
	return true

func toggle_flight() -> void:
	if is_flying:
		_try_land(false)
	elif _landing:
		return                                   # the descent finishes first; a take-off now would leave _landing pinning the fairy (GAP3-01)
	elif state == S.FREE and can_fly_here() and stamina >= float(GameData.player_cfg("flight_min_stamina", 15)):
		is_flying = true
		is_jumping = false
		_flight_time = 0.0
		z_index = Iso.Z_FLYING
		collision_mask = Iso.MASK_FLYING
		visual.play_action(&"takeoff")

func _update_vertical(delta: float) -> void:
	if is_flying:
		_flight_time += delta
		var climb := float(_climb_up) - float(_climb_down)
		var height := float(GameData.player_cfg("flight_altitude", 150))
		_altitude = clampf(_altitude + climb * float(GameData.player_cfg("flight_climb", 225)) * delta, 0.0, height * 1.8)
		if absf(climb) < 0.1:
			_altitude = move_toward(_altitude, height, delta * 100.0 * Iso.S)
		_spend_stamina(float(GameData.perk("flight_energy_per_second", 10)) * delta)
		if stamina <= 0.0 or _flight_time >= float(GameData.perk("flight_max_seconds", 8)):
			_try_land(true)
	elif _landing:
		if Iso.ground_dist(global_position, _landing_at) <= 8.0:
			_altitude = move_toward(_altitude, 0.0, delta * 220.0 * Iso.S)
			if _altitude == 0.0:
				_cancel_flight()
				visual.play_action(&"land")
	elif is_jumping:
		_vertical_speed -= float(GameData.player_cfg("gravity", 1750)) * delta
		_altitude = maxf(0.0, _altitude + _vertical_speed * delta)
		if _altitude == 0.0 and _vertical_speed < 0:
			is_jumping = false
			visual.play_action(&"land")
	visual.set_altitude(_altitude)

func _landing_safe(at: Vector2) -> bool:
	if not area.is_walkable(area.global_to_cell(at)):
		return false
	var body: CollisionShape2D = get_node("Body")
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = body.shape
	query.transform = Transform2D(0.0, at)
	query.collision_mask = Iso.MASK_WALKING
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

func _try_land(forced: bool) -> bool:
	if not is_flying:
		return false
	_landing_at = global_position
	if not _landing_safe(_landing_at):
		if not forced:
			EventBus.whisper_requested.emit("UI_NO_ROOM_TO_LAND")
			return false
		var found: Variant = _nearest_landing()
		if found == null:
			return false
		_landing_at = found
	is_flying = false
	_landing = true
	return true

## The nearest safe landing spot (a cell centre, by ground distance) or null. Searches square rings of cells outward and
## stops once a ring cannot hold anything nearer than the best spot found: sorting the whole map cost ~19 ms on the farm (GAP3-09).
func _nearest_landing() -> Variant:
	var origin := area.global_to_cell(global_position)
	var step := minf(Iso.ground_dist(area.cell_to_global(origin), area.cell_to_global(origin + Vector2i.RIGHT)),
		Iso.ground_dist(area.cell_to_global(origin), area.cell_to_global(origin + Vector2i.DOWN)))
	var slack := Iso.ground_dist(global_position, area.cell_to_global(origin))
	var best: Variant = null
	var best_d := INF
	for r in maxi(area.map.width, area.map.height) + 1:
		# every cell of ring r is at least r steps from the origin cell, the player at most `slack` away from its centre
		if r * step - slack > best_d:
			break
		var ring: Array[Vector2] = []
		for cell in _ring_cells(origin, r):
			if cell.x >= 0 and cell.y >= 0 and cell.x < area.map.width and cell.y < area.map.height and area.is_walkable(cell):
				ring.append(area.cell_to_global(cell))
		ring.sort_custom(func(a: Vector2, b: Vector2): return Iso.ground_dist(global_position, a) < Iso.ground_dist(global_position, b))
		for at in ring:
			var d := Iso.ground_dist(global_position, at)
			if d >= best_d:
				break
			if _landing_safe(at):
				best = at
				best_d = d
				break
	return best

## The cells at Chebyshev distance r around `origin` (the border of a (2r+1)-square).
static func _ring_cells(origin: Vector2i, r: int) -> Array[Vector2i]:
	if r == 0:
		return [origin]
	var cells: Array[Vector2i] = []
	for i in range(-r, r + 1):
		cells.append(origin + Vector2i(i, -r))
		cells.append(origin + Vector2i(i, r))
	for j in range(-r + 1, r):
		cells.append(origin + Vector2i(-r, j))
		cells.append(origin + Vector2i(r, j))
	return cells

func _cancel_flight() -> void:
	is_flying = false
	_climb_up = false
	_climb_down = false
	is_jumping = false
	_landing = false
	_altitude = 0.0
	_vertical_speed = 0.0
	collision_mask = Iso.MASK_WALKING
	z_index = 0
	if visual != null:
		visual.set_altitude(0.0)

func swing() -> bool:
	return combat.swing()

func dodge() -> bool:
	return combat.dodge()

func fairy_light() -> bool:
	return combat.fairy_light()

func drink() -> bool:
	return combat.drink()

func take_damage(amount: int, from: Vector2 = Vector2.ZERO) -> bool:
	return combat.take_damage(amount, from)

func cd_ratio(ability: String) -> float:
	return combat.cd_ratio(ability)

func cd_seconds(ability: String) -> float:
	return float(combat.cooldowns.get(ability, 0.0))

func begin_talk(at: Vector2 = Vector2.ZERO) -> void:
	if combat != null:
		combat.cancel_action()
	super.begin_talk(at)
	if at != Vector2.ZERO:
		event_face(at - global_position)

func end_talk() -> void:
	if state == S.TALKING and not _event_active:
		state = S.FREE
	forced_clip = &""

func event_begin() -> void:
	_event_active = true
	begin_talk()

func event_end() -> void:
	_event_generation += 1
	_event_active = false
	end_talk()

func event_face(direction: Vector2) -> void:
	if direction.length_squared() > 0.01:
		combat_aim = Iso.to_ground(direction).normalized()
		facing8 = Iso.dir8_of(direction)
		facing_vec = Iso.dir8_vector(facing8)
		visual.set_facing_direction(facing_vec)

func event_stand(at: Vector2, direction := "S") -> void:
	global_position = at
	velocity = Vector2.ZERO
	event_face(Iso.dir8_vector(maxi(0,Iso.DIR8_NAMES.find(direction))))

func event_walk_to(at: Vector2, speed: float = 185.0) -> bool:
	var generation := _event_generation
	var elapsed := 0.0
	while is_inside_tree() and generation == _event_generation and Iso.ground_dist(global_position, at) > 4.0 and elapsed < 20.0:
		var delta := get_physics_process_delta_time()
		var direction := Iso.to_ground(at - global_position).normalized()
		velocity = Iso.to_screen(direction * minf(speed, Iso.ground_dist(global_position, at) / maxf(delta, 0.001)))
		move_and_slide()
		event_face(Iso.to_screen(direction))
		visual.update_motion(velocity, false, false, false, facing_vec)
		elapsed += delta
		await get_tree().physics_frame
	velocity = Vector2.ZERO
	return generation == _event_generation and Iso.ground_dist(global_position, at) <= 4.0

func camera_focus(target: Variant, zoom: float, seconds: float = 0.25) -> void:
	if not controls.local_active() or area == null: return
	_camera_generation += 1
	var generation := _camera_generation
	if _camera_tween != null and _camera_tween.is_running(): _camera_tween.kill()
	_camera_zoom_before = _target_zoom
	var at: Vector2 = target.global_position if target is Node2D else target
	_camera_tween = create_tween().set_parallel(true)
	_camera_tween.tween_property(camera, "offset", at - global_position, seconds)
	_camera_tween.tween_property(camera, "zoom", Vector2.ONE * clampf(zoom, area.zoom_range.x, area.zoom_range.y), seconds)
	while is_inside_tree() and generation == _camera_generation and _camera_tween != null and _camera_tween.is_running():
		await get_tree().process_frame
	if is_inside_tree() and generation == _camera_generation: _apply_camera_limits()

func camera_release(seconds: float = 0.25) -> void:
	if not controls.local_active(): return
	_camera_generation += 1
	var generation := _camera_generation
	if _camera_tween != null and _camera_tween.is_running(): _camera_tween.kill()
	if not is_inside_tree() or area == null: return
	if seconds <= 0.0:
		camera.offset = Vector2.ZERO
		_set_zoom(_camera_zoom_before)
		return
	_camera_tween = create_tween().set_parallel(true)
	_camera_tween.tween_property(camera, "offset", Vector2.ZERO, seconds)
	_camera_tween.tween_property(camera, "zoom", Vector2.ONE * _camera_zoom_before, seconds)
	while is_inside_tree() and generation == _camera_generation and _camera_tween != null and _camera_tween.is_running():
		await get_tree().process_frame
	if is_inside_tree() and generation == _camera_generation: _set_zoom(_camera_zoom_before)
