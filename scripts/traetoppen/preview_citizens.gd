class_name TraetoppenPreviewCitizens
extends RefCounted
## PREVIEW CITIZENS of the treetop city (milestone M1a "city preview", lead amendment M1a-V4). HONEST STAND-INS: while P14's `npc` marker handler
## (scripts/world2d/npc_2d.gd, the real Npc2D) does not exist, every `npc` marker of the city gets a posed figure that can only be LOOKED AT:
##   * the baked idle sprite of the marker's cast id (lua/config/npcs.lua `visual`, with the fallback chain) through IsoChibiSprite2D.create, the
##     same path the player uses, facing the direction with the most open floor ahead, a soft shadow, a gentle idle breath;
##   * y-sorted at the level of the marker (z_index = the level's rank, or one above the owl-hole decals for a figure in a trunk hole);
##   * NO collision, NO interaction: a plain Node2D without a body, an Area2D or a prompt, not in the groups `npc` / `interactable`;
##   * a small name label in the built UI theme (the NamePlate variation with the Danish name from cast.csv / core.csv through the key
##     `npcs.<id>.name_key`, and the EnergyTag variation carrying TRAE_PREVIEW_TAG), keys only, never a literal.
## `PREVIEW_ONLY` is the visible marker of all this and attach() logs ONE line ("preview citizens: N placed, P14 absent") so nobody mistakes
## the figures for the real citizens. When P14 has landed (IsoArea.resolve_handler("npc") finds a handler) attach() returns 0 at once and places
## nothing: CityBuilder then asks the handler for the real Npc2D of every marker. Removed together with this file when P14 / the town director land.
##
## The name plates and tags are drawn on a z of their own (LABEL_Z, absolute, above every rank of the city): a plate sorted at its figure's rank was cut
## off by the rim of the deck in front of it (Brumme's "Tømrer ..." behind the Upper deck); plates that would overlap on screen (Pip and Oak stand side by
## side on deck B) are stacked, the later one above the earlier.
##
## PREVIEW HINTS (attach_hints): in M1a nothing else shows interaction prompts, whispers or toasts (the HUD, P17, and the toast scene do not exist yet:
## GameUI loads no `hud` screen), so a walker could not learn that E climbs the ladder or rides the Skovlift basket. The Hints overlay (a CanvasLayer
## in the city area) listens to EventBus.interaction_prompt_changed / whisper_requested / notification_posted and shows them as small plates; it hides
## itself as soon as a real HUD screen exists (GameUI.has_screen(&"hud")) and is not created at all once P14 has landed.
##
## The two Brumme markers carry `when=flag:brumme_at_work|brumme_at_stall` (V6's DailyFlags sets them). While neither flag exists the preview
## derives the same answer read-only from lua/config/traetoppen.lua `stall.weekdays` and TimeManager.weekday_index(), and a flag that exists wins.

const PREVIEW_ONLY := true
const TAG_KEY := "TRAE_PREVIEW_TAG"
const HOST_NAME := "PreviewCitizens"
const GROUP := &"preview_citizen"
const NAME_VARIATION := &"NamePlate"
const TAG_VARIATION := &"EnergyTag"
## A figure standing in a trunk hole is drawn just above the hole decals (data decor_ranks.owl_holes = 175).
const WINDOW_RANK_OFFSET := 1
const BREATH_AMPLITUDE := 0.012
const LABEL_HEAD_Y := -222.0
const LABEL_SCALE_MIN := 1.2
const LABEL_SCALE_MAX := 4.5
const LABEL_SCREEN_FACTOR := 0.6
## Plates and tags are drawn above every rank of the city (the highest level rank is 160, the lamps 161, the canopy is a CanvasLayer of its own).
const LABEL_Z := 2000
const LABEL_GAP_PX := 2.0
const HINTS_NAME := "PreviewHints"
const HINTS_LAYER := 4
const HINT_PROMPT_VARIATION := &"NamePlate"
const HINT_FONT_SIZE := 18
## The widest a hint plate grows before its text wraps (px; at most this share of the viewport width).
const HINT_MAX_WIDTH_PX := 880.0
const HINT_MAX_WIDTH_SHARE := 0.7
const HINT_WHISPER_S := 4.0
const HINT_TOAST_S := 4.0
const HUD_POLL_S := 0.5
const WHEN_POLL_S := 0.5
const FACING_STEPS := 6
const FACING_STEP_PX := 60.0

## Number of figures the last attach() placed (tests, the log line).
static var last_placed: int = 0


## True while a real `npc` marker handler exists (P14): the preview does nothing then.
static func inert() -> bool:
	return str(IsoArea.resolve_handler("npc")["kind"]) != "none"


## Places a preview citizen for every `npc` marker of `markers` (CityData.markers rows). Returns how many it placed (0 = inert or none).
static func attach(area: IsoArea, markers: Array[Dictionary], data: Dictionary, registry: LevelRegistry) -> int:
	last_placed = 0
	if inert():
		return 0
	var host := Host.new()
	host.name = HOST_NAME
	host.area = area
	area.add_child(host)
	var window_rank: int = LuaData.int_of(LuaData.dict(data.get("decor_ranks", {})).get("owl_holes", 175), 175) + WINDOW_RANK_OFFSET
	var placed: int = 0
	for m in markers:
		if str(m["type"]) != "npc":
			continue
		var cit: Node2D = _make_citizen(m, area, data, registry, window_rank, host)
		if cit != null:
			placed += 1
	last_placed = placed
	host.refresh_visibility()
	print("preview citizens: %d placed, P14 absent" % placed)
	return placed


## The prompt / whisper / toast overlay of the preview (see the header). Returns null when P14 has landed (a real HUD era: nothing to stand in for).
static func attach_hints(area: IsoArea) -> Node:
	if inert():
		return null
	var hints := Hints.new()
	hints.name = HINTS_NAME
	area.add_child(hints)
	print("preview hints: prompt / whisper / toast overlay placed, no HUD (P17) yet")
	return hints


static func _make_citizen(m: Dictionary, area: IsoArea, data: Dictionary, registry: LevelRegistry, window_rank: int, host: Host) -> Node2D:
	var npc_id: String = str(m["id"])
	var visual_id: String = str(GameData.cfg("npcs.%s.visual" % npc_id, ""))
	if visual_id == "":
		return null
	var window: bool = bool(m["window"])
	var level_id: StringName = StringName(str(m["level"]))
	var rank: int = window_rank if window else CityData.rank_of(data, level_id)
	var pos: Vector2 = m.get("pose", m["at"]) as Vector2
	var cit := Node2D.new()
	cit.name = "Preview_%s" % npc_id
	cit.position = area.to_local(pos)
	cit.z_index = rank
	cit.add_to_group(GROUP)
	cit.set_meta("preview_only", PREVIEW_ONLY)
	cit.set_meta("npc_id", npc_id)
	cit.set_meta("when", str(m["when"]))
	cit.set_meta("level", String(level_id))
	cit.set_meta("window", window)
	var visual: IsoChibiSprite2D = IsoChibiSprite2D.create(visual_id)
	if visual == null:
		cit.free()
		return null
	visual.name = "Visual"
	visual.show_shadow = not window
	visual.set_direction_index(_facing(npc_id, pos, level_id, registry, window))
	cit.add_child(visual)
	var name_key: String = str(GameData.cfg("npcs.%s.name_key" % npc_id, ""))
	var plate: Label = _label(name_key, NAME_VARIATION)
	var tag: Label = _label(TAG_KEY, TAG_VARIATION)
	for l in [plate, tag]:
		(l as Label).z_as_relative = false
		(l as Label).z_index = LABEL_Z
	cit.add_child(tag)
	cit.add_child(plate)
	area.objects.add_child(cit)
	if visual.shadow != null:
		# the shadow sits one step above the floor of the level (the chibi's own is the absolute z -5, under every deck)
		visual.shadow.z_as_relative = false
		visual.shadow.z_index = rank - 2
	host.add_citizen(cit, visual, plate, tag)
	return cit


static func _label(key: String, variation: StringName) -> Label:
	var l := Label.new()
	l.text = key
	l.theme_type_variation = variation
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.focus_mode = Control.FOCUS_NONE
	return l


## The direction row (0 S, 1 SW, 2 W ... 7 SE) a figure faces: the one with the most open floor of ITS level straight ahead (the nearest walkable
## direction is where the deck is), the cast's own facing (npcs.lua) winning a tie, the south (toward the camera) the next. A window figure keeps
## the cast's facing.
static func _facing(npc_id: String, pos: Vector2, level_id: StringName, registry: LevelRegistry, window: bool) -> int:
	var own: int = Iso.DIR8_NAMES.find(str(GameData.cfg("npcs.%s.facing" % npc_id, "S")))
	own = maxi(own, 0)
	if window or registry == null:
		return own
	var best: int = own
	var best_run: int = -1
	for i in 8:
		var d: int = (own + i) % 8
		var run: int = 0
		var step_dir: Vector2 = Iso.to_ground(Iso.dir8_vector(d)).normalized()
		for s in range(1, FACING_STEPS + 1):
			var probe: Vector2 = pos + Iso.to_screen(step_dir * FACING_STEP_PX * float(s))
			if registry.level_id_at(probe) == level_id:
				run += 1
			else:
				break
		if run > best_run:
			best_run = run
			best = d
	return best


## Re-evaluates a `when` of a citizen the way the real markers are (IsoArea.evaluate_when), with the preview's read-only Brumme rule.
static func wanted(spec: String) -> bool:
	if spec == "":
		return true
	var gm: Node = GameData.gm()
	if spec.begins_with("flag:") and gm != null:
		var flag: String = spec.get_slice(":", 1)
		if flag == "brumme_at_work" or flag == "brumme_at_stall":
			var work: Variant = gm.call("get_flag", &"brumme_at_work", null)
			var stall: Variant = gm.call("get_flag", &"brumme_at_stall", null)
			if work == null and stall == null:
				var tm: Node = GameData.tm()
				var weekday: int = int(tm.call("weekday_index")) if tm != null and tm.has_method("weekday_index") else 0
				var on_stall_day: bool = CityData.stall_weekdays().has(weekday)
				return on_stall_day if flag == "brumme_at_stall" else not on_stall_day
	return IsoArea.evaluate_when(spec)


## The node that keeps the figures alive: breath, label scale that follows the camera zoom, `when` polling. Lives under the area.
class Host extends Node:
	var area: IsoArea
	var citizens: Array[Dictionary] = []     # {node, visual, plate, tag, phase}
	var _t: float = 0.0
	var _poll: float = 0.0

	func add_citizen(node: Node2D, visual: IsoChibiSprite2D, plate: Label, tag: Label) -> void:
		var rec: Dictionary = {"node": node, "visual": visual, "plate": plate, "tag": tag, "phase": float(citizens.size()) * 1.7}
		citizens.append(rec)
		for l in [plate, tag]:
			(l as Label).minimum_size_changed.connect(_fit.bind(rec))
		_fit(rec)

	## Sizes a label to its text and pivots it on its middle (the scale below grows it around the middle).
	func _fit(rec: Dictionary) -> void:
		for key in ["plate", "tag"]:
			var l: Label = rec[key]
			if is_instance_valid(l):
				var ms: Vector2 = l.get_combined_minimum_size()
				l.size = ms
				l.pivot_offset = ms * 0.5

	## The name plate above the head and the tag above the plate, both centred on the figure; `s` = the plate's scale (the tag is 0.8 of it).
	func _place(rec: Dictionary, s: float) -> void:
		var plate: Label = rec["plate"]
		var tag: Label = rec["tag"]
		plate.scale = Vector2.ONE * s
		tag.scale = Vector2.ONE * s * 0.8
		plate.position = Vector2(-plate.size.x * 0.5, TraetoppenPreviewCitizens.LABEL_HEAD_Y - plate.size.y * 0.5)
		var tag_y: float = TraetoppenPreviewCitizens.LABEL_HEAD_Y - (plate.size.y * 0.5 + tag.size.y * 0.4) * s - 3.0 * s
		tag.position = Vector2(-tag.size.x * 0.5, tag_y - tag.size.y * 0.5)

	func refresh_visibility() -> void:
		for rec in citizens:
			var node: Node2D = rec["node"]
			if is_instance_valid(node):
				node.visible = TraetoppenPreviewCitizens.wanted(str(node.get_meta("when", "")))

	func _process(delta: float) -> void:
		_t += delta
		_poll += delta
		if _poll >= TraetoppenPreviewCitizens.WHEN_POLL_S:
			_poll = 0.0
			refresh_visibility()
		var cam: Camera2D = get_viewport().get_camera_2d() if is_inside_tree() else null
		var zoom: float = cam.zoom.x if cam != null else 0.4
		var label_scale: float = clampf(TraetoppenPreviewCitizens.LABEL_SCREEN_FACTOR / maxf(zoom, 0.01), TraetoppenPreviewCitizens.LABEL_SCALE_MIN, TraetoppenPreviewCitizens.LABEL_SCALE_MAX)
		for rec in citizens:
			var node: Node2D = rec["node"]
			if not is_instance_valid(node) or not node.visible:
				continue
			var visual: Node2D = rec["visual"]
			var s: float = sin(_t * 1.7 + float(rec["phase"]))
			visual.scale = Vector2(1.0 - TraetoppenPreviewCitizens.BREATH_AMPLITUDE * 0.5 * s, 1.0 + TraetoppenPreviewCitizens.BREATH_AMPLITUDE * s)
			_place(rec, label_scale)
		_separate()

	## The block of a figure's labels (tag + plate) in world space, as drawn (a label is scaled around its middle).
	func block_of(rec: Dictionary) -> Rect2:
		var node: Node2D = rec["node"]
		var out := Rect2()
		var first: bool = true
		for key in ["plate", "tag"]:
			var l: Label = rec[key]
			var r := Rect2(node.global_position + l.position + l.pivot_offset - l.pivot_offset * l.scale, l.size * l.scale)
			out = r if first else out.merge(r)
			first = false
		return out

	## Plates that would overlap on screen are stacked: the later figure's block moves up above the earlier one (Pip and Oak stand side by side on deck B).
	## Runs after _place every frame, so a figure that is hidden (a `when`) or a zoom that separates them lets the plates fall back by themselves.
	func _separate() -> void:
		var taken: Array[Rect2] = []
		for rec in citizens:
			var node: Node2D = rec["node"]
			if not is_instance_valid(node) or not node.visible:
				continue
			var base: Rect2 = block_of(rec)
			var shift: float = 0.0
			for _pass in 6:
				var moved := Rect2(base.position + Vector2(0.0, shift), base.size)
				var hit: int = -1
				for i in taken.size():
					if moved.intersects(taken[i]):
						hit = i
						break
				if hit < 0:
					break
				shift = taken[hit].position.y - TraetoppenPreviewCitizens.LABEL_GAP_PX - base.end.y
			if shift != 0.0:
				for key in ["plate", "tag"]:
					(rec[key] as Label).position.y += shift
			rec["shift"] = shift
			taken.append(Rect2(base.position + Vector2(0.0, shift), base.size))


## The prompt / whisper / toast overlay of the preview (see the header): three small plates on a CanvasLayer above the canopy. Prompt text of
## the player's nearest interactable at the bottom (the key glyph of the `interact` action in front when the text has none, e.g. "Klatre" -> "E: Klatre"),
## the last whisper above it (translated key, HINT_WHISPER_S), the last notification at the top under the canopy (title + message, HINT_TOAST_S).
## Hidden while a real HUD screen exists.
class Hints extends CanvasLayer:
	var prompt: Label
	var whisper: Label
	var toast: Label
	var hud_present_now: bool = false
	var _whisper_left: float = 0.0
	var _toast_left: float = 0.0
	var _poll: float = 0.0

	func _init() -> void:
		layer = TraetoppenPreviewCitizens.HINTS_LAYER

	func _ready() -> void:
		prompt = _make_label("Prompt")
		whisper = _make_label("Whisper")
		toast = _make_label("Toast")
		EventBus.interaction_prompt_changed.connect(on_prompt)
		EventBus.whisper_requested.connect(on_whisper)
		EventBus.notification_posted.connect(on_toast)
		get_viewport().size_changed.connect(_layout)
		_layout()
		refresh_hud()

	func _exit_tree() -> void:
		if EventBus.interaction_prompt_changed.is_connected(on_prompt):
			EventBus.interaction_prompt_changed.disconnect(on_prompt)
		if EventBus.whisper_requested.is_connected(on_whisper):
			EventBus.whisper_requested.disconnect(on_whisper)
		if EventBus.notification_posted.is_connected(on_toast):
			EventBus.notification_posted.disconnect(on_toast)

	func _make_label(label_name: String) -> Label:
		var l := Label.new()
		l.name = label_name
		l.theme_type_variation = TraetoppenPreviewCitizens.HINT_PROMPT_VARIATION
		l.add_theme_font_size_override("font_size", TraetoppenPreviewCitizens.HINT_FONT_SIZE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.focus_mode = Control.FOCUS_NONE
		l.visible = false
		add_child(l)
		return l

	## Prompt and whisper stand centred above the bottom edge, the toast centred under the canopy; every plate is as wide as its text (set_text).
	func _layout() -> void:
		for l in [prompt, whisper, toast]:
			var c: Label = l
			c.anchor_left = 0.5
			c.anchor_right = 0.5
			c.offset_left = 0.0
			c.offset_right = 0.0
			c.grow_horizontal = Control.GROW_DIRECTION_BOTH
		prompt.anchor_top = 1.0
		prompt.anchor_bottom = 1.0
		prompt.offset_bottom = -84.0
		prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
		whisper.anchor_top = 1.0
		whisper.anchor_bottom = 1.0
		whisper.offset_bottom = -138.0
		whisper.grow_vertical = Control.GROW_DIRECTION_BEGIN
		toast.anchor_top = 0.0
		toast.anchor_bottom = 0.0
		toast.offset_top = 124.0
		for l in [prompt, whisper, toast]:
			set_text(l, (l as Label).text)

	func max_width() -> float:
		return minf(get_viewport().get_visible_rect().size.x * TraetoppenPreviewCitizens.HINT_MAX_WIDTH_SHARE, TraetoppenPreviewCitizens.HINT_MAX_WIDTH_PX)

	## A plate as wide as its text; a text wider than max_width() wraps at that width.
	func set_text(l: Label, text: String) -> void:
		l.text = text
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.custom_minimum_size = Vector2.ZERO
		if l.get_combined_minimum_size().x > max_width():
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(max_width(), 0.0)

	## "Klatre" -> "E: Klatre" (the glyph of the first keyboard key of the `interact` action); a text that already starts with it stays.
	static func with_key(text: String) -> String:
		var glyph: String = key_glyph()
		if text == "" or glyph == "" or text.begins_with(glyph + ":"):
			return text
		return "%s: %s" % [glyph, text]

	static func key_glyph() -> String:
		for ev in InputMap.action_get_events(&"interact"):
			if ev is InputEventKey:
				var k: InputEventKey = ev
				var code: Key = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
				return OS.get_keycode_string(code)
		return ""

	## True while the real HUD (GameUI screen `hud`, P17) exists: it owns prompts, whispers and toasts then.
	static func hud_present(tree: SceneTree) -> bool:
		if tree == null:
			return false
		for n in tree.get_nodes_in_group(&"game_ui"):
			if n.has_method("has_screen") and bool(n.call("has_screen", &"hud")):
				return true
		return false

	func on_prompt(text: String) -> void:
		set_text(prompt, with_key(text))
		prompt.visible = text != ""

	func on_whisper(key: String) -> void:
		set_text(whisper, tr(key))
		whisper.visible = true
		_whisper_left = TraetoppenPreviewCitizens.HINT_WHISPER_S

	func on_toast(title: String, message: String, _icon: String) -> void:
		var text: String = title if message == "" else "%s\n%s" % [title, message]
		if text == "":
			return
		set_text(toast, text)
		toast.visible = true
		_toast_left = TraetoppenPreviewCitizens.HINT_TOAST_S

	## Advances the timers of the whisper and the toast; _process calls it with the frame time.
	func tick(delta: float) -> void:
		if _whisper_left > 0.0:
			_whisper_left -= delta
			if _whisper_left <= 0.0:
				whisper.visible = false
		if _toast_left > 0.0:
			_toast_left -= delta
			if _toast_left <= 0.0:
				toast.visible = false
		_poll += delta
		if _poll >= TraetoppenPreviewCitizens.HUD_POLL_S:
			_poll = 0.0
			refresh_hud()

	## Hides the whole overlay while a real HUD exists.
	func refresh_hud() -> void:
		hud_present_now = hud_present(get_tree())
		visible = not hud_present_now

	func _process(delta: float) -> void:
		tick(delta)
