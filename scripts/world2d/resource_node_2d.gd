class_name ResourceNode2D
extends Interactable2D
## Owns its hits and stable identity. The loot owner owns every generated-floor roll.
var kind := "moss_patch"
var cfg: Dictionary = {}
var area: IsoArea
var cell := Vector2i.ZERO
var context: Dictionary = {}
var uid := ""
var hp := 1
var depleted := false
var picking := false
var remaining: float = 0
var _picker: Player2D
var _picture: Sprite2D
var _solid: StaticBody2D
var _glow: Sprite2D
var _day_key := ""
var _shake: Tween
static func create_marker(params: Dictionary, pos: Vector2, at: Vector2i, target: IsoArea) -> Node:
	var ctx := LootMarkers.context_for(target,at)
	if LootMarkers.is_done(target,at,ctx): return null
	var row := LuaData.dict(Svc.lua_config("resource_nodes."+str(params.get("kind","moss_patch")),{}))
	if row.is_empty(): return null
	var node := ResourceNode2D.new()
	node.kind = str(params.get("kind","moss_patch"))
	node.cfg = row.duplicate(true)
	node.area = target
	node.cell = at
	node.context = ctx
	node.uid = str(ctx.uid)
	node.position = pos
	node.name = "Resource_"+node.kind+"_"+str(at.x)+"_"+str(at.y)
	return node
func _ready() -> void:
	super._ready()
	add_to_group("resource_node")
	_day_key = "resource_day_"+str(DungeonRng.hash_key(uid,0,0))
	var art := ArtCatalog.prop(StringName(str(cfg.art)))
	_picture = Sprite2D.new()
	_picture.texture = art.texture
	_picture.centered = false
	_picture.offset = -art.pivot
	add_child(_picture)
	EventBus.season_changed.connect(_season_art)
	_season_art(GameManager.season)
	var glow := LuaData.dict(art.get("glow",{}))
	if not glow.is_empty():
		_glow = Sprite2D.new()
		_glow.texture = glow.texture
		_glow.position = Vector2(glow.center)-Vector2(art.pivot)
		_glow.scale = Vector2(glow.size)/Vector2(glow.texture.get_size())
		_glow.modulate = Color(glow.color,.65)
		_glow.material = Glow.additive_material()
		add_child(_glow)
	if not bool(cfg.get("forage",false)):
		_solid = StaticBody2D.new()
		_solid.collision_layer = Iso.LAYER_RESOURCE_NODE
		_solid.collision_mask = 0
		var shape := CollisionShape2D.new()
		var ellipse := ConvexPolygonShape2D.new()
		ellipse.points = Enemy2D._ellipse(35,20)
		shape.shape = ellipse
		_solid.add_child(shape)
		add_child(_solid)
	EventBus.day_started.connect(_morning)
	_refresh()
	set_process(false)
func _refresh() -> void:
	var day := int(Svc.node("GameManager").get_flag(StringName(_day_key),0))
	depleted = int(context.get("floor",0)) <= 0 and day > 0 and Svc.node("GameManager").total_day()-day < int(cfg.get("respawn_days",1))
	hp = int(cfg.get("hp",1))
	_appearance()
func _morning(_day: int, _season: StringName) -> void:
	if int(context.get("floor",0)) <= 0: _refresh()
func _appearance() -> void:
	_picture.modulate = Color(.35,.35,.4,.5) if depleted else Color.WHITE
	if _glow != null: _glow.visible = not depleted
	if _solid != null: _solid.set_deferred("collision_layer",0 if depleted or not _enabled else Iso.LAYER_RESOURCE_NODE)
	_area.set_deferred("collision_layer",0 if depleted or not _enabled else Iso.LAYER_INTERACTABLE)
func set_enabled(on: bool) -> void:
	super.set_enabled(on)
	if not on and picking:
		picking = false
		_release_picker()
		set_process(false)
	if is_instance_valid(_picture): _appearance()
func get_interaction_prompt() -> String:
	if depleted or picking: return ""
	return tr("FOREST_PROMPT_PICK") if bool(cfg.get("forage",false)) else tr("FOREST_PROMPT_CHOP") if str(cfg.get("tool","")) == "axe" else tr("FOREST_PROMPT_MINE")
func interact(player: Node) -> void:
	if not _enabled or depleted or picking: return
	if not bool(cfg.get("forage",false)):
		if player is Player2D and str(GameData.item_def(player.hotbar.current()).get("tool_type","")) == str(cfg.get("tool","")):
			player.use_selected()
			return
		EventBus.whisper_requested.emit("FOREST_TOOL_AXE" if str(cfg.get("tool","")) == "axe" else "FOREST_TOOL_PICKAXE")
		return
	if not player is Player2D: return
	picking = true
	remaining = .6
	_picker = player
	_picker.begin_talk(global_position)
	_picker.visual.play_action(&"interact",maxf(.1,_picker.visual.clip_duration(&"interact")/.6))
	set_process(true)
func _process(dt: float) -> void:
	if not picking: return
	if not is_instance_valid(_picker) or _picker.state != Player2D.S.TALKING or _picker.area != area:
		picking = false
		_release_picker()
		set_process(false)
		return
	remaining -= dt
	if remaining > 0: return
	picking = false
	_release_picker()
	deplete()
	set_process(false)
func _release_picker() -> void:
	if is_instance_valid(_picker) and _picker.state == Player2D.S.TALKING:
		_picker.end_talk()
		_picker.visual.cancel_action()
	_picker = null
func tool_hit(tool: String, power: int, _player: Node = null) -> bool:
	if not _enabled or depleted or picking or bool(cfg.get("forage",false)): return false
	if tool != str(cfg.get("tool","")) or power < int(cfg.get("power",1)):
		EventBus.whisper_requested.emit("FOREST_TOOL_WEAK")
		return false
	hp -= 1
	if _shake != null and _shake.is_valid(): _shake.kill()
	_picture.position = Vector2.ZERO
	_shake = create_tween()
	_shake.tween_property(_picture,"position:x",6.0,.05)
	_shake.tween_property(_picture,"position:x",-4.0,.06)
	_shake.tween_property(_picture,"position:x",0.0,.06)
	if hp <= 0: return deplete()
	return true
func deplete() -> bool:
	if not _enabled or depleted: return false
	var rows := []
	if int(context.get("floor",0)) > 0:
		var loot := Svc.node("LootService")
		var ctx := context.duplicate()
		ctx["deliver"] = "orbs"
		var result: Dictionary = loot.node_loot(kind,uid,ctx) if loot != null else {"ok":false}
		if not result.get("ok",false):
			hp = 1
			return false
		rows = result.get("results",[])
		LootMarkers.mark_done(area,cell,context)
	else:
		var gm := Svc.node("GameManager")
		var rng := DungeonRng.new(DungeonRng.hash_key(uid,gm.total_day(),0))
		var amounts := LuaData.arr(cfg.get("amount",[1,1]))
		rows.append({"id":str(cfg.item),"amount":rng.range_i(int(amounts[0]),int(amounts[1]))})
		if rng.chance_bp(roundi(float(cfg.get("rare_gem_chance",0))*10000)):
			rows.append({"id":["amethyst","crystal_shard","emerald"][rng.below(3)],"amount":1})
		gm.set_flag(StringName(_day_key),gm.total_day())
	depleted = true
	_appearance()
	for row in rows: LootDrop2D.spawn(area.objects,global_position+Vector2(0,16),row.id,int(row.amount))
	# These grants are still on the ground. Legacy collect objectives also listen
	# to this signal's direct grants, so only item_gained may count these orbs.
	EventBus.resource_node_depleted.emit(StringName(uid),[])
	return true
func _exit_tree() -> void:
	_release_picker()

## The art package is optional: an absent seasonal sibling keeps the base
## painting without recording a missing-art fallback or changing harvest rules.
func _season_art(season: StringName) -> void:
	var id := str(cfg.get("art",""))+"_"+str(season)
	if not ArtCatalog.has_real_prop(StringName(id)):id = str(cfg.get("art",""))
	if is_instance_valid(_picture):
		var art := ArtCatalog.prop(StringName(id))
		_picture.texture = art.texture
		_picture.offset = -art.pivot
