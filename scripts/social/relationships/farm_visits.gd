class_name FarmVisits
extends Node
## Disposable home actors; persistent dates, guests and gifts stay in the existing
## social/home sections. The route overlay keeps every work interval intact.
const HOME := "farm.porch"
static var _cache: Dictionary = {}
var room: HomeRoom
var actors: Dictionary = {}
var _pending := false

static func attach(target: HomeRoom) -> Node:
	var node := FarmVisits.new()
	node.name = "FarmVisits"
	node.room = target
	target.add_child(node)
	return node

static func friends(week: int,tag: String) -> Array[String]:
	var out: Array[String] = []
	for npc in SocialManager.friend_ids():
		if SocialManager.can_befriend(npc) and SocialManager.hearts(npc)>=4 and npc!=str(SocialManager.partner().get("id","")):out.append(npc)
	out.sort_custom(func(a,b):return SocialManager.roll([tag,week,a])<SocialManager.roll([tag,week,b]))
	return out

static func visitor(week: int,index: int) -> String:
	var list := friends(week,"home_visit")
	var previous := HomeManager.visit_today()
	if int(previous.get("week",-1))==week and int(previous.get("index",-1))==index:return str(previous.get("npc",""))
	list = list.filter(func(npc):return SocialManager.event_stamp("home_visit:"+npc)!=week+1)
	return list[index % list.size()] if index>=0 and not list.is_empty() else ""

static func context() -> Dictionary:
	var p := SocialManager.partner()
	var partner := str(p.get("id","")) if int(p.get("stage",0))==3 else ""
	var ids: Array = HomeManager.party_today()
	var visit := str(HomeManager.visit_today().get("npc",""))
	if visit!="" and not ids.has(visit):ids.append(visit)
	if partner!="" and not ids.has(partner):ids.append(partner)
	return {"home_guests":ids,"home_partner":partner}

static func _protected(npc: String,ctx: Dictionary,base: Array) -> Array:
	var intervals: Array = []
	for s in base:
		if str(s.kind)=="stay" and str(s.get("act","")) in ["work","tend","lamp","guard","patrol"]:intervals.append(s)
	for bid in Hours.registry():
		var b := Hours.building(str(bid))
		if str(b.get("keeper",""))!=npc or not b.has("hours") or int(ctx.weekday) in Hours.closed_days(b):continue
		var hours := Hours.hours_on(b,int(ctx.weekday))
		for s in base:
			if str(s.kind)!="stay" or float(s.t1)<=float(hours[0]) or float(s.t0)>=float(hours[1]):continue
			var protected: Dictionary = s.duplicate()
			protected.t0 = maxf(float(s.t0),float(hours[0]))
			protected.t1 = minf(float(s.t1),float(hours[1]))
			intervals.append(protected)
	intervals.sort_custom(func(a,b):return float(a.t0)<float(b.t0))
	return intervals

static func _covered(protected: Array,over: Array) -> bool:
	for s in protected:
		if not over.any(func(o):return str(o.kind)=="stay" and str(o.get("place",""))==str(s.place) and float(o.t0)<=float(s.t0)+0.00001 and float(o.t1)>=float(s.t1)-0.00001):return false
	return true

static func timeline(npc: String,ctx: Dictionary,base: Array) -> Array:
	if not npc in ctx.get("home_guests",[]) or not LuaData.dict(ctx.get("fest",{})).is_empty() or base.is_empty():return base
	var morning := npc==str(ctx.get("home_partner",""))
	var key := "%s|%s|%s|%s" % [npc,ctx.weekday,ctx.get("weather","klart"),morning]
	if _cache.has(key) and is_same(_cache[key].base,base):return _cache[key].out
	var protected := _protected(npc,ctx,base)
	var out := base
	if morning and not protected.is_empty():
		var first: Dictionary = protected[0]
		var travel := Routines._move_seg(HOME,str(first.place),0.0,npc)
		var seconds := RouteTable.seconds(HOME,str(first.place))/Routines.speed_mult(npc)
		var leave := float(first.t0)-maxf(float(travel.t1),seconds*2.0/60.0)-5.0/60.0
		if leave>6.05 and leave<12.0:
			var move := Routines._move_seg(HOME,str(first.place),leave,npc)
			var candidate: Array = [{"kind":"stay","place":HOME,"act":"home","t0":6.0,"t1":leave},move,{"kind":"stay","place":first.place,"act":first.get("act","stand"),"t0":move.t1,"t1":first.t1}]
			for s in base:
				if float(s.t0)>=float(first.t1)-0.00001:candidate.append(s)
			if _covered(protected,candidate):out = candidate
	# Try the largest available evening visit. Failed candidates are local planning
	# attempts, never bad authored routes or a replacement for work coverage.
	var evening := false
	for start in [19.0,19.5,20.0,20.5,21.0]:
		if evening:break
		for end in [22.0,21.5,21.0,20.5,20.0]:
			if float(end)-float(start)<0.5:continue
			var n := Routines.compile_problems.size()
			var candidate := Routines._overlay(out,{"from":start,"to":end,"at":HOME},npc+"/home")
			var clean := Routines.compile_problems.size()==n
			Routines.compile_problems.resize(n)
			if not clean or not _covered(protected,candidate):continue
			candidate = candidate.duplicate(true)
			for s in candidate:
				if str(s.kind)=="stay" and str(s.get("place",""))==HOME:s["act"] = "home" if float(s.t0)<22.0 and float(s.t1)<=22.00001 else "inside"
			out = candidate
			evening = true
			break
	if _cache.size()>=64:_cache.clear()
	_cache[key] = {"base":base,"out":out}
	return out

static func partner_at_home() -> String:
	var p := SocialManager.partner()
	if int(p.get("stage",0))!=3:return ""
	var npc := str(p.get("id",""))
	return npc if str(Routines.where_is(npc,Routines.now_ctx()).get("act",""))=="home" else ""

static func daily_chore() -> void:
	var p := SocialManager.partner()
	var day := SocialManager.today()
	if int(p.get("stage",0))!=3 or day<=int(p.get("married",day)) or int(p.get("chore_day",0))>=day:return
	var tree := Engine.get_main_loop() as SceneTree
	var world := tree.get_first_node_in_group("world_2d") if tree!=null else null
	if world==null or world.get("farm")==null:return
	var farm: FarmGrid = world.get("farm")
	EconomyManager.defer_notifications(func() -> void:
		var water := 0
		for plot in farm.plots.values():
			if int(plot.state) in [FarmGrid.State.PLANTED,FarmGrid.State.WATERED] and not plot.watered:water += 1
		if water>0:
			SocialManager.commit_chore(day,"water",mini(water,12))
			farm.water_unwatered(12)
		else:
			var fed := AnimalHusbandry.feed_from_supplies(func(n):SocialManager.commit_chore(day,"feed",n))
			if fed==0:SocialManager.commit_chore(day,"note",0)
		EconomyManager.after_transaction(func() -> void:
			var done := SocialManager.partner()
			var key := "PARTNER_CHORE_"+str(done.get("chore_kind","note")).to_upper()
			var message := TranslationServer.translate(key)
			if str(done.get("chore_kind",""))=="water":message = message % int(done.get("chore_count",0))
			EventBus.notification_posted.emit(SocialManager._name_of(str(done.id)),message,"social"))
	)

func _ready() -> void:
	EventBus.day_started.connect(func(_day,_season):schedule())
	EventBus.time_of_day_changed.connect(func(_h,_m):schedule())
	EventBus.game_event.connect(func(id,_data):
		if id in [&"relationship_changed",&"festival_held"]:schedule())
	EventBus.modal_changed.connect(func(_stack):
		if not GameManager.is_modal_open():schedule())
	EventBus.visitor_gift.connect(func(_npc,_item):schedule())
	EventBus.furniture_changed.connect(func(_score):schedule())
	schedule()

func schedule() -> void:
	if not _pending:
		_pending = true
		refresh.call_deferred()

func refresh() -> void:
	_pending = false
	if not is_instance_valid(room) or not is_inside_tree():return
	if GameManager.is_modal_open():
		return # Keep the speaker alive; the next minute/visit refresh reconciles it.
	var ctx := Routines.now_ctx()
	var wanted: Array[String] = []
	for guest in HomeManager.guests_today():
		var npc := str(guest.npc)
		if str(Routines.where_is(npc,ctx).get("act",""))=="home":wanted.append(npc)
	for npc in actors.keys():
		if npc not in wanted:
			actors[npc].queue_free()
			actors.erase(npc)
	var cells: Array = room.grid.reachable().keys()
	cells = cells.filter(func(c):return Vector2(c).distance_to(Vector2(room.grid.door_cell))>=2.0 and Vector2(c).distance_to(Vector2(room.grid.spawn_cell))>=2.0)
	cells.sort_custom(func(a,b):return Vector2(a).distance_squared_to(Vector2(room.grid.spawn_cell))<Vector2(b).distance_squared_to(Vector2(room.grid.spawn_cell)))
	var taken: Array[Vector2i] = []
	for npc in wanted:
		var cell := Vector2i(-999,-999)
		for c in cells:
			if taken.all(func(other):return Vector2(c).distance_to(Vector2(other))>=2.5):cell = c;break
		if cell.x == -999:continue
		taken.append(cell)
		var actor: Npc2D = actors.get(npc)
		if not is_instance_valid(actor):
			actor = Npc2D.create({"id":npc,"guest":true,"wander":"0","facing":"S"})
			actor.name = "HomeGuest_"+npc
			actor.area = room.area
			actor.position = HomeData.cell_to_local(Vector2(cell))
			room.world.add_child(actor)
			actors[npc] = actor
		actor.set_guest_home(room.world.to_global(HomeData.cell_to_local(Vector2(cell))))
