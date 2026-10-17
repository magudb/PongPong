extends Node
## World audio follows current state. No save data or new autoload.
var area_id := ""
var _world: WeakRef
var _ambience := ""
var _music := ""
var _festival := false
var _bell_stamp := ""
func _ready() -> void:
	EventBus.area_changed.connect(_area)
	EventBus.time_of_day_changed.connect(_clock)
	EventBus.weather_changed.connect(func(_weather):refresh())
	EventBus.day_started.connect(func(_day,_season):refresh())
	EventBus.game_event.connect(_event)
	EventBus.item_purchased.connect(func(_item,_amount,_cost):_sfx("coin_clink"))
	EventBus.gold_changed.connect(func(_total,delta):
		if delta>0:_sfx("coin_clink"))
	EventBus.friend_changed.connect(func(_npc,_hearts):_sfx("heart_up"))
	EventBus.crop_harvested.connect(func(_plot,_crop,_amount):_sfx("pickup_soft"))
	EventBus.quest_accepted.connect(func(_quest):_sfx("page_turn"))
	EventBus.quest_completed.connect(func(_quest):_sfx("stage_up"))
	EventBus.whisper_requested.connect(_whisper)
	EventBus.modal_changed.connect(func(_stack):_sfx("page_turn"))
	var world := get_tree().get_first_node_in_group("world_2d")
	if world!=null and world.area!=null:_area(world.area.map.id)
func _live() -> bool:
	return _world!=null and is_instance_valid(_world.get_ref()) and _world.get_ref().is_inside_tree()
func _sfx(id: String) -> void:
	if _live():AudioManager.play_sfx(id)
func _shop(id: String) -> bool:
	return id.begins_with("int_") and str(Hours.building(id.trim_prefix("int_")).get("kind","")) in ["shop","service"]
func _area(id: StringName) -> void:
	var world := get_tree().get_first_node_in_group("world_2d")
	if world==null:return
	var old := area_id
	var changed := old!=str(id)
	area_id = str(id)
	_world = weakref(world)
	if not world.tree_exiting.is_connected(_leave):world.tree_exiting.connect(_leave,CONNECT_ONE_SHOT)
	if changed and (_shop(old) or _shop(area_id)):AudioManager.play_sfx("shop_bell")
	if changed and (old.begins_with("int_") or area_id.begins_with("int_") or old=="home" or area_id=="home"):AudioManager.play_sfx("door_open_wood")
	refresh()
func _leave() -> void:
	_world = null
	area_id = ""
	_ambience = ""
	_music = ""
	_festival = false
	AudioManager.duck_ambience(0)
	AudioManager.stop_world_audio()
func refresh() -> void:
	if not _live():return
	var key := "interior" if area_id.begins_with("int_") else "moerkeskoven" if area_id.begins_with("moerkeskoven_f") else area_id
	var data := LuaData.dict(Svc.lua_config("audio_map.areas."+key,{}))
	var world: Node = _world.get_ref()
	var cave: bool = world.area!=null and world.area.map.ambient==&"cave"
	var ambient := "cave_drip" if cave else str(data.get("night" if TimeManager.is_night() else "day",""))
	if ambient!=_ambience:
		_ambience = ambient
		AudioManager.play_ambience(ambient,float(Svc.lua_config("audio_map.fade",1.5)))
	AudioManager.play_rain(not cave and TimeManager.weather in [&"regn",&"torden"] and not area_id.begins_with("int_") and area_id!="home")
	var festival := str(SocialManager.festival_active())!=""
	AudioManager.duck_ambience(-6 if festival else 0)
	_festival = festival
	# Generated-floor scoring belongs to DungeonCues; the director never replaces it on clock ticks.
	if area_id.begins_with("moerkeskoven_f"):return
	var music := "festival_"+str(GameManager.season) if festival else str(data.get("music",""))
	if music!=_music:
		_music = music
		if music=="":AudioManager.stop_music()
		else:AudioManager.play_music(music)
func _clock(_hour: int,_minute: int) -> void:refresh()
func _whisper(key: String) -> void:
	if key in ["HOURS_CLOSED_NOW","HOURS_CLOSED_DAY","HOURS_CLOSED_FESTIVAL","HOURS_HOME_LOCKED","HOURS_HOME_AWAY","HOURS_HOME_STRANGER"]:_sfx("door_locked_knock")
func _event(id: StringName,data: Dictionary) -> void:
	if not _live():return
	var cue := str(Svc.lua_config("audio_map.events."+str(id),""))
	if cue!="":_sfx(cue)
	match id:
		&"equipment_changed":
			if str(data.get("slot",""))=="weapon":_sfx("weapon_equip")
			elif str(ItemKinds.def(str(data.get("item",""))).get("category",""))=="gem":_sfx("gem_set")
		&"town_festival_started":
			_sfx("festival_horn")
			refresh()
		&"town_festival_ended":refresh()
		&"closing_warning",&"shop_open_changed":
			var row := Hours.building(area_id.trim_prefix("int_")) if area_id.begins_with("int_") else {}
			if not row.is_empty() and str(row.get("shop",area_id.trim_prefix("int_")))==str(data.get("shop","")) and (id==&"closing_warning" or not bool(data.get("open",true))):_sfx("closing_bell")
		&"routine_changed":
			var hour := int(data.get("hour",-1))
			var stamp := "%d:%d" % [GameManager.total_day(),hour]
			if area_id=="traetoppen" and hour in [12,18] and stamp!=_bell_stamp:
				_bell_stamp = stamp
				_sfx("town_bell")
