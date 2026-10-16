class_name IsoChibiSprite2D
extends Node2D
## Animated 8-direction sprite. Draw origin is the character's ground contact point.
## The textures are 8 rows (S, SW, W, NW, N, NE, E, SE), with frames in columns (cell 256x256, pivot (128, 200)).
## No 3D mesh or 3D runtime dependency.
##
## One generic scene (scenes/isometric/chibi.tscn = Node2D + Shadow + Sprite) serves EVERY character; build one with
##     var hero := IsoChibiSprite2D.create("fox")
## Characters are open: any id with res://assets/isometric_characters/<id>/animations.json exists (no id list, no enum).
## An id without art falls back along the chain in lua/config/characters.lua (hobbit_pip -> raccoon until its art lands).
##
## Merged from the pack script, the gameplay patch (facing_override, play_action(clip, rate), clip_duration, has_clip,
## is_action_playing, cancel_action, set_spin, flash, get_portrait, preload_clips, awaitable warm_clips, shadow on an
## absolute floor z) and the open-id patch.
##
## CONTRACT WardrobeLayers (F5) depends on, keep stable (tested: characters.wardrobe_contract_members):
##   child node named "Sprite" = the property `sprite` (Sprite2D, region_enabled), child "Shadow" = `shadow`;
##   `current_clip`, `direction_index`; `base_sprite_offset` (READ-ONLY, the UNROTATED sprite.offset: the sprite's real
##   offset differs from it while set_spin() shifts the rotation pivot); set_altitude(), flash(), set_spin();
##   sibling halos are inserted BEFORE `Sprite` (move_child), clothes are mirrored by WardrobeLayers itself from
##   sprite.position / rotation / scale / modulate / (offset - base_sprite_offset), nothing more is needed here
##   (sprite.scale carries `display_scale` = 1.0 for every shipped character; the root node's own scale stays free for callers).

signal action_finished(clip_name: StringName)

const FRAME_SIZE := 256
const GROUND_ANCHOR_Y := 200
const TEXTURE_EXTENSION := ".webp"
const CHARACTERS_DIR := "res://assets/isometric_characters/"
const SCENE_PATH := "res://scenes/isometric/chibi.tscn"
const DEFAULT_ID := "fox"
## The shadow lives on the FLOOR layer (above the ground tiles z=-10, below every y-sorted object) whatever z_index the
## character has: a flying Fe has z_index 20 and a relative -1 would draw her shadow over trees and houses.
const SHADOW_Z := -5
## CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS (CanvasItem enum 4, NOT the project-setting enum where 3 is "Nearest Mipmap").
const SPRITE_FILTER := CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

# Safe defaults for a character folder whose animations.json carries no `animations` table.
const BASE_ANIMATIONS := {
	"idle": {"frames": 4, "fps": 5, "loop": true},
	"walk": {"frames": 6, "fps": 9, "loop": true},
	"run": {"frames": 6, "fps": 12, "loop": true},
	"jump": {"frames": 4, "fps": 10, "loop": false},
	"fall": {"frames": 3, "fps": 6, "loop": true},
	"land": {"frames": 3, "fps": 11, "loop": false},
	"celebrate": {"frames": 6, "fps": 9, "loop": false},
	"interact": {"frames": 4, "fps": 9, "loop": false},
	"hit": {"frames": 3, "fps": 11, "loop": false},
	"sleep": {"frames": 4, "fps": 3, "loop": true},
	"talk": {"frames": 4, "fps": 6, "loop": true},
}
const FLIGHT_ANIMATIONS := {
	"takeoff": {"frames": 4, "fps": 10, "loop": false},
	"hover": {"frames": 5, "fps": 8, "loop": true},
	"fly": {"frames": 6, "fps": 12, "loop": true},
	"flight_land": {"frames": 4, "fps": 10, "loop": false},
}
## Pack fliers: only used to pick the default clip set when animations.json has no clip table.
const FLIER_IDS := ["bat", "fairy"]

## Parsed animations.json per art id (shared by all instances; never mutated after parsing).
static var _meta_cache: Dictionary = {}

## The id the caller asked for (e.g. "hobbit_pip"). `resolved_id` is the art folder really in use (e.g. "raccoon").
@export var character_id: String = DEFAULT_ID
@export_range(0.5, 2.5, 0.05) var playback_rate: float = 1.0
@export_range(0, 7, 1) var starting_direction: int = 0
@export var show_shadow: bool = true

@onready var sprite: Sprite2D = $Sprite
@onready var shadow: Sprite2D = $Shadow

var current_clip: StringName = &"idle"
var direction_index: int = 0
## The art folder in use after the fallback chain (== character_id when the character has its own art).
var resolved_id: String = ""
## From animations.json: role (player|npc|enemy|boss|critter|farm_animal; pack characters carry none = full clip set = "player").
var role: String = "player"
var family: String = ""
var flyer: bool = false
## From animations.json: sprite scale (1.0 for every shipped character: sprites are never scaled individually, the camera zooms).
var display_scale: float = 1.0
## From animations.json: {color: Color, radius_px: float, strength: float} for glowing creatures (halo is baked into the
## sheets, this is the data for a light/halo of the world), {} otherwise.
var glow: Dictionary = {}
## The UNROTATED sprite offset (feet on the node origin). Read-only: `sprite.offset` differs while set_spin() is active.
var base_sprite_offset: Vector2:
	get:
		return _base_sprite_offset

var _frame: int = 0
var _frame_timer: float = 0.0
var _animations: Dictionary = {}
var _textures: Dictionary = {}
var _locked: bool = false
var _altitude: float = 0.0
var _shadow_origin_scale: Vector2 = Vector2.ONE
var _action_rate: float = 1.0          # per-action playback multiplier (1.0 = clip fps)
var _spin: float = 0.0                 # radians, used by the dodge roll
var _spin_pivot_height: float = 44.0   # px above the feet (unscaled sprite space) that the roll rotates around
var _base_sprite_offset: Vector2 = Vector2.ZERO
var _flash_tween: Tween
var _portrait_file: String = "portrait.webp"
var _loaded: bool = false
var _direction_explicit: bool = false  # a direction was chosen by a call: _ready() must not reset it to starting_direction
var _altitude_set: bool = false        # set_altitude() was called (before or after _ready): the shadow alpha follows _altitude
# cache of the running clip (set by _cache_clip): the per-frame code touches no Dictionary
var _clip_frames: int = 1
var _clip_fps: float = 6.0
var _clip_loop: bool = false


## The one way to build a character: instantiates scenes/isometric/chibi.tscn and loads the art (with the fallback chain
## of lua/config/characters.lua). Add the result to the tree; the sprite binds to its nodes in _ready.
## Configuration between create() and add_child() is kept: set_direction_index(), set_facing_direction() (or a direct
## `direction_index =`), set_altitude(), set_spin(), display_scale + refresh_visual_scale(), playback_rate. `starting_direction`
## is only the initial facing of a scene placed in the editor; any explicit direction wins over it (characters.configure_before_add_child).
static func create(id: String) -> IsoChibiSprite2D:
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		push_error("IsoChibiSprite2D.create: %s is missing" % SCENE_PATH)
		return null
	var node := packed.instantiate() as IsoChibiSprite2D
	if node == null:
		push_error("IsoChibiSprite2D.create: %s root is not an IsoChibiSprite2D" % SCENE_PATH)
		return null
	node.load_character(id)
	return node


## True when `id` (or something in its fallback chain) has art.
static func character_exists(id: String) -> bool:
	return CharacterCatalog.resolve(id) != ""


## The art folder an id draws with ("" = none): the first id of its fallback chain that has an animations.json.
static func resolve_id(id: String) -> String:
	return CharacterCatalog.resolve(id)


## Forget the parsed animations.json of every character (tests, hot reload of art).
static func clear_cache() -> void:
	_meta_cache.clear()


## Normalised content of one animations.json text: {animations{clip:{frames,fps,loop,sheet}}, role, family, flyer,
## display_scale, glow, portrait}. A text that is not a JSON object gives the defaults of the pack.
static func parse_meta(id: String, text: String) -> Dictionary:
	var flier := id in FLIER_IDS
	var source: Dictionary = {}
	var json := JSON.new()
	if text != "" and json.parse(text) == OK and json.data is Dictionary:
		source = json.data
	if source.has("flyer"):
		flier = bool(source["flyer"])
	var clips := BASE_ANIMATIONS.duplicate(true)
	if flier:
		clips.merge(FLIGHT_ANIMATIONS.duplicate(true), true)
	var declared: Variant = source.get("animations", {})
	if declared is Dictionary and not (declared as Dictionary).is_empty():
		clips = declared
	var anims: Dictionary = {}
	for clip in clips.keys():
		var raw: Variant = clips[clip]
		if not raw is Dictionary:
			continue
		var spec := raw as Dictionary
		# StringName keys: play_loop/has_clip take StringName and are called every tick per character.
		var key := StringName(str(clip))
		anims[key] = {
			"frames": maxi(int(spec.get("frames", 1)), 1),
			"fps": maxf(float(spec.get("fps", 6.0)), 0.5),
			"loop": bool(spec.get("loop", false)),
			"sheet": String(spec.get("sheet", str(clip) + TEXTURE_EXTENSION)),
		}
	var scale_value := float(source.get("display_scale", 1.0))
	var glow_data: Dictionary = {}
	var glow_raw: Variant = source.get("glow", null)
	if glow_raw is Dictionary and not (glow_raw as Dictionary).is_empty():
		var g := glow_raw as Dictionary
		glow_data = {
			"color": Color.from_string(str(g.get("color", "#ffffff")), Color.WHITE),
			"radius_px": float(g.get("radius_px", 0.0)),
			"strength": float(g.get("strength", 1.0)),
		}
	return {
		"animations": anims,
		"role": String(source.get("role", "player")),
		"family": String(source.get("family", "")),
		"flyer": flier,
		"display_scale": scale_value if scale_value > 0.0 else 1.0,
		"glow": glow_data,
		"portrait": String(source.get("portrait", "portrait.webp")),
	}


## Parsed animations.json of an art folder (cached).
static func meta_for(art_id: String) -> Dictionary:
	if _meta_cache.has(art_id):
		return _meta_cache[art_id]
	var text := ""
	var path := CHARACTERS_DIR + art_id + "/animations.json"
	if FileAccess.file_exists(path):
		text = FileAccess.get_file_as_string(path)
	var meta := parse_meta(art_id, text)
	_meta_cache[art_id] = meta
	return meta


func _ready() -> void:
	_shadow_origin_scale = shadow.scale
	shadow.visible = show_shadow
	shadow.z_as_relative = false
	shadow.z_index = SHADOW_Z
	shadow.texture_filter = SPRITE_FILTER
	sprite.region_enabled = true
	sprite.texture_filter = SPRITE_FILTER
	_base_sprite_offset = Vector2(0.0, float(FRAME_SIZE) * 0.5 - GROUND_ANCHOR_Y)
	sprite.offset = _base_sprite_offset
	# `starting_direction` is the initial facing of an editor-placed scene; a direction chosen before add_child() stays.
	if not _direction_explicit and direction_index == 0:
		direction_index = clampi(starting_direction, 0, 7)
	if not _loaded:
		load_character(character_id)
	else:
		refresh_visual_scale()
		_sync_sprite()


## Loads a character by id. Any id with an animations.json works; an id without art uses its fallback chain
## (lua/config/characters.lua); an id nothing resolves for warns and shows DEFAULT_ID.
func load_character(id: String) -> void:
	var art := CharacterCatalog.resolve(id)
	if art == "":
		push_warning("Unknown chibi character: %s" % id)
		id = DEFAULT_ID
		art = CharacterCatalog.resolve(id)
		if art == "":
			art = id
	character_id = id
	resolved_id = art
	var meta := meta_for(art)
	_animations = meta["animations"]
	role = meta["role"]
	family = meta["family"]
	flyer = meta["flyer"]
	display_scale = meta["display_scale"]
	glow = (meta["glow"] as Dictionary).duplicate()
	_portrait_file = meta["portrait"]
	_textures.clear()
	_locked = false
	_action_rate = 1.0
	current_clip = &"idle"
	_frame = 0
	_frame_timer = 0.0
	_cache_clip()
	_loaded = true
	refresh_visual_scale()
	_sync_sprite()


## Faces a sheet row directly: 0 S, 1 SW, 2 W, 3 NW, 4 N, 5 NE, 6 E, 7 SE (turn arrows of a preview, tests).
func set_direction_index(index: int) -> void:
	_direction_explicit = true
	var next_direction := clampi(index, 0, 7)
	if direction_index != next_direction:
		direction_index = next_direction
		_sync_sprite()


func set_facing_direction(movement: Vector2) -> void:
	if movement.length_squared() < 0.001:
		return
	_direction_explicit = true
	# S=0, SW=1, W=2, NW=3, N=4, NE=5, E=6, SE=7.
	var clockwise_from_south := fposmod(-atan2(movement.x, movement.y), TAU)
	var next_direction := wrapi(int(round(clockwise_from_south / (PI / 4.0))), 0, 8)
	if direction_index != next_direction:
		direction_index = next_direction
		_sync_sprite()


## Drives the locomotion clips from the body's motion. `facing_override`: the game moves in GROUND units (screen y is
## squashed), so facing must come from the INPUT direction, not from the squashed velocity, or analog sticks pick the
## wrong sprite row near sector borders.
func update_motion(
	motion: Vector2,
	running: bool = false,
	airborne: bool = false,
	flying: bool = false,
	facing_override: Vector2 = Vector2.ZERO
) -> void:
	set_facing_direction(facing_override if facing_override != Vector2.ZERO else motion)
	if _locked:
		return
	var selected: StringName = &"idle"
	if flying:
		selected = &"fly" if motion.length_squared() > 100.0 else &"hover"
	elif airborne:
		selected = &"fall"
	elif motion.length_squared() > 90.0:
		selected = &"run" if running else &"walk"
	play_loop(selected)


func play_loop(clip: StringName) -> void:
	if clip != current_clip and _animations.has(clip):
		_play(clip)


## Plays a clip once and locks locomotion until it ends (then back to idle, action_finished is emitted).
## `rate` multiplies the clip's fps for this play only.
func play_action(clip: StringName, rate: float = 1.0) -> void:
	if not _animations.has(clip):
		return
	_locked = true
	_action_rate = rate
	_play(clip, true)


## True while a non-looping action clip (swing, hit, jump...) is playing.
func is_action_playing() -> bool:
	return _locked


## Seconds one full play of `clip` takes at the given rate (0.0 for a clip the character does not have).
func clip_duration(clip: StringName, rate: float = 1.0) -> float:
	var spec: Dictionary = _animations.get(clip, {})
	if spec.is_empty():
		return 0.0
	return float(spec["frames"]) / maxf(float(spec["fps"]) * playback_rate * rate, 0.5)


func has_clip(clip: StringName) -> bool:
	return _animations.has(clip)


## Names of every clip this character has (the role's clip set: player = all 11, + 4 flight clips for fliers).
func get_clip_names() -> PackedStringArray:
	var out := PackedStringArray()
	for k in _animations.keys():
		out.append(String(k))
	return out


## How many clip sheets this sprite holds resident right now (idle after load, +1 per clip played or warmed).
## warm_clips() raises it by at most ONE per frame (characters.warm_clips_one_sheet_per_frame).
func resident_clip_count() -> int:
	return _textures.size()


## Frame count and fps of a clip ({} when absent).
func get_clip_spec(clip: StringName) -> Dictionary:
	var spec: Dictionary = _animations.get(clip, {})
	return spec.duplicate()


func cancel_action() -> void:
	_locked = false
	_action_rate = 1.0


## Rotates the figure about its body centre (dodge roll). 0 resets.
func set_spin(angle: float) -> void:
	_spin = angle
	_apply_sprite_transform()


## Soft colour flash on the Sprite child (damage tint is thorn-berry pink, never red). Duration in seconds.
func flash(tint: Color, duration: float = 0.25) -> void:
	if sprite == null or not is_inside_tree():
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	sprite.modulate = tint
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "modulate", Color.WHITE, duration)


## The pack's own portrait of the art folder in use (a full-body crop; busts for dialogue are resolved by TTPortraits).
func get_portrait() -> Texture2D:
	var path := CHARACTERS_DIR + resolved_id + "/" + _portrait_file
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## Loads sheets ahead of use on worker threads (call during a fade). Returns immediately.
func preload_clips(clips: Array) -> void:
	for clip in clips:
		var path := _sheet_path(StringName(str(clip)))
		if path != "":
			ResourceLoader.load_threaded_request(path)


## Awaitable warm-up: sheets are requested on worker threads and FINALISED ONE PER FRAME, because the GPU upload of a
## 12 MB sheet costs ~20 ms on the main thread (measured). Call it behind the area fade; afterwards the first use of a
## clip no longer hitches. `clips` = clip names (e.g. ["idle", "walk", "run", "interact"]).
func warm_clips(clips: Array) -> void:
	if not is_inside_tree():
		return
	var keys: Array[StringName] = []
	var paths: Dictionary = {}
	var resident: Dictionary = {}
	for clip in clips:
		var key := StringName(str(clip))
		if _animations.has(key) and not _textures.has(key) and not paths.has(key):
			var path := _sheet_path(key)
			if path != "":
				keys.append(key)
				paths[key] = path
				resident[key] = ResourceLoader.has_cached(path)
				ResourceLoader.load_threaded_request(path)
	for key in keys:
		while ResourceLoader.load_threaded_get_status(paths[key]) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if not is_inside_tree():
				return
			await get_tree().process_frame
		var tex := ResourceLoader.load_threaded_get(paths[key]) as Texture2D
		if tex != null:
			_textures[key] = tex
		if not is_inside_tree():
			return
		# A prefetched/reused texture is already uploaded; no extra idle frame.
		if not bool(resident[key]):
			await get_tree().process_frame


## Applies display_scale and the altitude to the sprite and the shadow (call after changing `display_scale`; load_character
## and _ready do it, so settings made between create() and add_child() land here).
func refresh_visual_scale() -> void:
	if sprite == null or shadow == null:
		return
	_apply_sprite_transform()
	shadow.scale = _shadow_origin_scale * display_scale * (1.0 + minf(_altitude / 400.0, 0.28))
	if _altitude_set:
		var tint := shadow.modulate
		tint.a = lerpf(0.50, 0.20, clampf(_altitude / 135.0, 0.0, 1.0))
		shadow.modulate = tint


func _apply_sprite_transform() -> void:
	if sprite == null:
		return
	# Rotating a Sprite2D turns it about its own origin (the feet). To roll about the body centre we move the node up by
	# the pivot height and push the texture down by the same amount (in sprite space; the node scale makes it display_scale x).
	var pivot: float = _spin_pivot_height if absf(_spin) > 0.0001 else 0.0
	sprite.scale = Vector2(display_scale, display_scale)
	sprite.rotation = _spin
	sprite.position.y = -_altitude - pivot * display_scale
	sprite.offset = _base_sprite_offset + Vector2(0.0, pivot)


func _play(clip: StringName, force: bool = false) -> void:
	if clip == current_clip and not force:
		return
	if not _animations.has(clip):
		clip = &"idle"
	if not _animations.has(clip):
		return
	# Maintain stride continuity when changing walk/run state.
	var old_frames: int = _clip_frames
	var stride_transition := current_clip in [&"walk", &"run"] and clip in [&"walk", &"run"]
	var phase := float(_frame) / float(maxi(old_frames, 1))
	current_clip = clip
	_cache_clip()
	_frame = clampi(int(phase * _clip_frames), 0, _clip_frames - 1) if stride_transition else 0
	_frame_timer = 0.0
	_sync_sprite()


func _cache_clip() -> void:
	var spec: Dictionary = _animations.get(current_clip, {})
	_clip_frames = int(spec.get("frames", 1))
	_clip_fps = float(spec.get("fps", 6.0))
	_clip_loop = bool(spec.get("loop", false))


## Lifts the sprite `height_pixels` above its shadow (a flying fairy); the shadow stays on the floor, fades and widens.
## Also valid before add_child(): the value is stored and applied in _ready.
func set_altitude(height_pixels: float) -> void:
	_altitude = maxf(height_pixels, 0.0)
	_altitude_set = true
	refresh_visual_scale()


func _process(delta: float) -> void:
	if _animations.is_empty():
		return
	var fps: float = maxf(_clip_fps * playback_rate * (_action_rate if _locked else 1.0), 0.5)
	_frame_timer += delta
	var frame_length := 1.0 / fps
	while _frame_timer >= frame_length:
		_frame_timer -= frame_length
		_frame += 1
		if _frame >= _clip_frames:
			if _clip_loop:
				_frame = 0
			else:
				_frame = _clip_frames - 1
				var completed := current_clip
				_locked = false
				_action_rate = 1.0
				_play(&"idle", true)
				action_finished.emit(completed)
				return
		_sync_sprite()


## res://.../<art id>/<sheet> of a clip ("" when the character does not have it).
func _sheet_path(clip_key: StringName) -> String:
	var spec: Dictionary = _animations.get(clip_key, {})
	if spec.is_empty():
		return ""
	return CHARACTERS_DIR + resolved_id + "/" + String(spec.get("sheet", String(clip_key) + TEXTURE_EXTENSION))


func _sync_sprite() -> void:
	if not is_node_ready() or not _animations.has(current_clip):
		return
	var clip_key := current_clip
	if not _textures.has(clip_key):
		_textures[clip_key] = load(_sheet_path(clip_key)) as Texture2D
	var image := _textures[clip_key] as Texture2D
	if image == null:
		_textures.erase(clip_key)
		push_error("Unable to load character sprite sheet: %s/%s" % [resolved_id, clip_key])
		return
	sprite.texture = image
	sprite.region_rect = Rect2(
		float(_frame * FRAME_SIZE), float(direction_index * FRAME_SIZE),
		float(FRAME_SIZE), float(FRAME_SIZE)
	)
