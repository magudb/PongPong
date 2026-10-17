class_name FarmDress
extends Node2D
## A disposable marker owns only a derived prop; never save cosmetic state.
const RESERVE := preload("res://scripts/farm/steading/objects/farm_reserve.gd")
var area: IsoArea
var cell := Vector2i.ZERO
var params: Dictionary = {}
var prop: Node2D
var valid := false
var _connected := false

static func create_marker(values: Dictionary,_position: Vector2,at: Vector2i,target: IsoArea) -> Node:
	var node := FarmDress.new()
	node.params = values.duplicate()
	node.area = target
	node.cell = at
	return node

func _ready() -> void:
	add_to_group("farm_dress")
	var conditions := 0
	for key in ["tier","season","event"]:
		if str(params.get(key,""))!="":conditions += 1
	valid = conditions==1 and str(params.get("prop",""))!="" and ArtCatalog.has_real_prop(StringName(str(params.get("prop",""))))
	if valid:
		var art := ArtCatalog.prop_metadata(StringName(str(params.prop)))
		var footprint := LuaData.arr(art.get("footprint",[1,1]))
		for y in range(cell.y-int(footprint[1])+1,cell.y+1):
			for x in range(cell.x-int(footprint[0])+1,cell.x+1):
				if RESERVE.blocked(area,Vector2i(x,y))!="":valid = false
	if not valid:
		area.map.errors.append("dress needs one condition, reviewed art and a footprint outside reserved cells: "+str(params))
	_connect()
	refresh()

func _enter_tree() -> void:
	if is_node_ready():
		_connect()
		refresh.call_deferred()
func _exit_tree() -> void:
	if not _connected:return
	for pair in [[EventBus.home_upgraded,_home],[EventBus.season_changed,_season],[EventBus.day_started,_day],[EventBus.flag_changed,_flag],[EventBus.game_event,_event]]:
		if pair[0].is_connected(pair[1]):pair[0].disconnect(pair[1])
	_connected = false
func _connect() -> void:
	if _connected:return
	EventBus.home_upgraded.connect(_home)
	EventBus.season_changed.connect(_season)
	EventBus.day_started.connect(_day)
	EventBus.flag_changed.connect(_flag)
	EventBus.game_event.connect(_event)
	_connected = true

func active() -> bool:
	if params.has("tier"):return GameManager.flag_int(&"home_tier",1)>=int(params.tier)
	if params.has("season"):return str(GameManager.season)==str(params.season)
	var value: Variant = GameManager.get_flag(StringName(str(params.get("event",""))),false)
	return value if value is bool else float(value)!=0.0 if typeof(value) in [TYPE_INT,TYPE_FLOAT] else str(value)!=""

func refresh() -> void:
	if not valid or not is_inside_tree() or not is_instance_valid(area):return
	if active() and not is_instance_valid(prop):prop = area.place_prop(str(params.prop),cell)
	elif not active() and is_instance_valid(prop):
		area.remove_prop(prop)
		prop = null
func _home(_old: int,_new: int) -> void:refresh()
func _season(_value: StringName) -> void:refresh()
func _day(_value: int,_season_id: StringName) -> void:refresh()
func _flag(key: StringName,_value: Variant) -> void:
	if str(key)==str(params.get("event","")) or key==&"home_tier":refresh()
func _event(id: StringName,_data: Dictionary) -> void:
	if id in [&"home_exterior_ready",&"farm_stage_changed",&"town_festival_started",&"town_festival_ended"]:refresh()
