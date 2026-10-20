class_name FestivalStage
extends Node2D
## Area-owned, disposable hosts. Annual completion stays in SocialManager's save.
const ACTIVITY := preload("res://scripts/social/events/festival_interactable.gd")
var festival_id := ""
var area: IsoArea
var director: SocialEventDirector
var hosts: Array[Interactable2D] = []
var _busy := false

static func attach(parent: IsoArea,id: String,owner_director: Node) -> Node:
	var stage := FestivalStage.new()
	stage.festival_id = id
	stage.area = parent
	stage.director = owner_director
	stage.name = "FestivalStage"
	parent.objects.add_child(stage)
	return stage

func _ready() -> void:
	EventBus.game_event.connect(_event)
	EventBus.time_of_day_changed.connect(func(_h,_m): _refresh())
	set_physics_process(true)

func _physics_process(_delta: float) -> void:
	for town in NpcDirector._active:
		if is_instance_valid(town) and town.area == area and town.ready_for_population:
			set_physics_process(false)
			_build(town)
			return

func _build(town: TownDirector) -> void:
	if not is_inside_tree(): return
	var taken: Array[Vector2] = []
	for row in LuaData.arr(SocialData.festival(festival_id).get("activities",[])):
		var at := NpcDirector.post_ground(str(area.map.id),StringName(str(row.get("post",""))))
		if at == Vector2.INF:
			area.map.errors.append({"code":"festival_post","message":"unknown activity post "+str(row.get("post",""))})
			continue
		var candidates := _candidates(town,at)
		candidates = candidates.filter(func(candidate):return taken.all(func(previous):return previous.distance_to(candidate) >= 90.0))
		candidates.sort_custom(func(a,b):return a.distance_squared_to(at) < b.distance_squared_to(at))
		if candidates.is_empty():
			area.map.errors.append({"code":"festival_post","message":"no clear activity cell "+str(row.get("post",""))})
			continue
		var target := candidates[0]
		taken.append(target)
		var host: Interactable2D = ACTIVITY.new()
		host.activity = LuaData.dict(row).duplicate(true)
		host.stage = self
		host.position = to_local(area.to_global(Iso.to_screen(target)))
		add_child(host)
		hosts.append(host)
	_refresh()
	attendance()

func _candidates(town: TownDirector,at: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if town.nav != null:
		var cell := area.global_to_cell(area.to_global(Iso.to_screen(at)))
		for y in range(cell.y-3,cell.y+4):
			for x in range(cell.x-3,cell.x+4):
				var c := Vector2i(x,y)
				if town.nav.astar.is_in_boundsv(c) and not town.nav.blocked.has(c): result.append(Iso.to_ground(area.to_local(area.cell_to_global(c))))
	elif town.level_nav != null:
		var city := CityBuilder.of(area)
		var level := city.registry.level_at(area.to_global(Iso.to_screen(at)))
		if level == null: return result
		var index := -1
		for i in town.level_nav.levels.size():
			if str(town.level_nav.levels[i].id) == str(level.id): index = i
		for radius in [0.0,100.0,200.0]:
			for turn in 12:
				var point := at+Vector2.from_angle(TAU*turn/12.0)*float(radius)
				var safe := town.level_nav.snap(point,index)
				if bool(safe.get("ok",false)): result.append(safe.pos)
	return result

func current() -> bool:
	return is_inside_tree() and str(SocialManager.festival_active()) == festival_id

func _refresh() -> void:
	for host in hosts:
		if is_instance_valid(host): host.set_enabled(current())

func stamp(id: String) -> String:
	return "activity:"+festival_id+":"+id
func done(id: String) -> bool:
	return SocialManager.event_stamp(stamp(id)) >= GameManager.year
func _mark(id: String) -> void:
	SocialManager.mark_event_seen(stamp(id),GameManager.year)

func _event(id: StringName,payload: Dictionary) -> void:
	if id == &"chat_done" and current(): attendance(str(payload.get("npc","")))
	if id in [&"town_festival_started",&"town_festival_ended"]: _refresh()

func attendance(npc := "") -> void:
	if not current(): return
	var meta := LuaData.dict(SocialData.festival(festival_id).get("meta",{}))
	var who := str(meta.get("host","")) if npc == "" else npc
	if who == "" or SocialManager.event_stamp("attendance:"+festival_id+":"+who) >= GameManager.year: return
	SocialManager.mark_event_seen("attendance:"+festival_id+":"+who,GameManager.year)
	SocialManager.add_points(who,int(meta.get("attend_points",20)),&"festival")
	if SocialManager.festival_attended_year(festival_id) < GameManager.year:
		SocialManager.mark_festival_attended(festival_id,GameManager.year)
		EventBus.game_event.emit(&"festival_attended",{"id":festival_id})

func potluck_count() -> int:
	var from := float(SocialManager.festival_window(festival_id).from)
	var now := GameManager.hour+GameManager.minute/60.0
	var town := mini(11,6+maxi(0,floori(now-from)))
	return mini(12,town+GameManager.flag_int(StringName("potluck_"+festival_id+"_"+str(GameManager.year))))

func perform(activity: Dictionary) -> void:
	if _busy or not current() or GameManager.is_modal_open(): return
	_busy = true
	var id := str(activity.get("id",""))
	var kind := str(activity.get("kind",""))
	if kind != "market" and kind != "potluck" and done(id):
		EventBus.whisper_requested.emit("SOC_EV_DONE")
		_busy = false
		return
	var meta := LuaData.dict(SocialData.festival(festival_id).get("meta",{}))
	var host := str(meta.get("host",""))
	match kind:
		"market":
			var shop := str(activity.get("shop",""))
			if ShopSystem.has_shop(shop): ShopSystem.open_shop(shop)
		"contest","potluck":
			if kind == "potluck" and potluck_count() >= 12:
				_notice(tr("SOC_EV_POTLUCK") % 12)
			else:
				var choices := FestivalActivities.options(str(activity.get("select","")))
				if choices.is_empty(): EventBus.whisper_requested.emit("SOC_EV_EMPTY")
				else:
					var game_ui := get_tree().get_first_node_in_group("game_ui")
					var picker: Node = game_ui.get_screen(&"gift_ui")
					var item: String = await picker.choose(str(activity.get("name_key","SOC_EV_TITLE")),choices)
					if is_inside_tree() and current() and item != "" and FestivalActivities.options(str(activity.get("select",""))).any(func(row):return str(row.id) == item):
						if kind == "contest": _contest(activity,item)
						else:
							var key := StringName("potluck_"+festival_id+"_"+str(GameManager.year))
							EconomyManager.consume_backpack_items({item:1},func(): GameManager.set_flag(key,GameManager.flag_int(key)+1))
							_notice(tr("SOC_EV_POTLUCK") % potluck_count())
		"feast":
			_mark(id)
			var player := PlayerRegistry.local_player(get_tree())
			if player != null:
				player.heal_full()
				player.restore_stamina(player.max_stamina)
			_notice(tr("SOC_EV_FEAST"))
		"wish":
			var options: Array = []
			for wish in ["HOME","FRIENDS","COURAGE"]:
				options.append({"id":wish.to_lower(),"text_key":"SOC_EV_WISH_"+wish,"reply_key":"SOC_EV_WISH_REPLY","flag":"wish_"+festival_id+"_"+str(GameManager.year)})
			_queue_activity(id,host,[{"act":"say","who":host,"text_key":"SOC_EV_WISH_PROMPT"},{"act":"choice","options":options}],20)
		"dance":
			var roster := SocialManager.festival_roster(festival_id)
			var attendees: Array = [roster.host]+roster.gather
			attendees = attendees.filter(func(n): return str(n) != "" and NpcDirector.is_present(str(n)))
			attendees.sort_custom(func(a,b):return SocialManager.hearts(a)>SocialManager.hearts(b) if SocialManager.hearts(a)!=SocialManager.hearts(b) else str(a)<str(b))
			var partner := str(attendees[0]) if not attendees.is_empty() else host
			_queue_activity(id,partner,[{"act":"say","who":partner,"text_key":"SOC_EV_DANCE"},{"act":"emote","who":partner,"kind":"heart"},{"act":"wait","time":1.5}],30)
		"scene":
			_queue_activity(id,host,[{"act":"say","who":host,"text_key":str(activity.get("text_key","SOC_EV_FEAST"))}],0)
	if is_inside_tree():
		_busy = false
		if not GameManager.is_modal_open(): SaveManager.autosave()

func _queue_activity(id: String,who: String,steps: Array,points: int) -> void:
	var data := {"meta":{"npc":who,"trigger":"festival","once_per_year":true},"steps":steps,"rewards":{"points":points}}
	director.request(stamp(id),true,data)

func _contest(activity: Dictionary,item: String) -> Dictionary:
	var items := {}
	for name in ItemKinds.all_ids(): items[name] = ItemKinds.def(name)
	var prizes := LuaData.dict(LuaData.dict(SocialData.festival(festival_id).get("rewards",{})).get("contest",{}))
	var result := FestivalActivities.contest(item,str(activity.get("select","")),prizes,items,SocialManager.world_seed,festival_id,GameManager.year)
	if not result.ok: return result
	var committed := [false]
	EconomyManager.defer_notifications(func() -> void:
		committed[0] = EconomyManager.consume_backpack_items({item:1},func() -> void:
			_mark(str(activity.id))
			var prize := LuaData.dict(result.prize)
			SocialManager.owe_event_items(LuaData.dict(prize.get("items",{})))
			EconomyManager.add_gold(int(prize.get("gold",0)))
		)
	)
	if not committed[0]: return {"ok":false,"reason":"stock"}
	_notice(tr("SOC_EV_CONTEST_RESULT") % int(result.rank))
	return result

func _notice(text: String) -> void:
	EventBus.notification_posted.emit(tr(str(LuaData.dict(SocialData.festival(festival_id).get("meta",{})).get("name_key","SOC_EV_TITLE"))),text,"social")
