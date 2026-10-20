class_name HomeServices
extends RefCounted
const ROYAL := "ev_home_royal_visit"
static func world() -> WorldRoot2D:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.get_first_node_in_group("world_2d") as WorldRoot2D if tree!=null else null
static func at_home() -> bool:
	var host := world()
	return host!=null and host.area!=null and host.area.map.id==&"home"
static func royal_reason(home_menu := false) -> String:
	if not HomeManager.unlocked("royal_visit"):return "tier"
	if SocialManager.event_seen(ROYAL):return "done"
	if not at_home():return "away"
	if GameManager.hour<19 or GameManager.hour>=22:return "hours"
	if str(SocialManager.festival_active())!="":return "festival"
	if not HomeManager.party_today().is_empty():return "busy"
	var host := world()
	var director := SocialManager.get_node_or_null("EventDirector") as SocialEventDirector
	var menu := home_menu and GameManager.top_modal() in [&"home_chest",&"home_amenities"]
	if host.traveling or host.sleeping or director==null or director.runner.active!="" or (GameManager.is_modal_open() and not menu):return "busy"
	var king := Routines.where_is("fairy_king",Routines.now_ctx())
	if str(king.get("act","")) in ["work","guard","patrol","sleep"]:return "busy"
	return ""
static func invite_king() -> bool:
	if royal_reason()!="":return false
	var host := world()
	var room := host.area.get_node_or_null("HomeRoom") as HomeRoom
	if room==null:return false
	var cells: Array = room.grid.reachable().keys()
	cells = cells.filter(func(c):return Vector2(c).distance_to(Vector2(room.grid.door_cell))>=2 and Iso.ground_dist(host.player.global_position,room.area.to_global(HomeData.cell_to_local(Vector2(c))))>=150)
	cells.sort_custom(func(a,b):return room.area.to_global(HomeData.cell_to_local(Vector2(a))).distance_squared_to(host.player.global_position)<room.area.to_global(HomeData.cell_to_local(Vector2(b))).distance_squared_to(host.player.global_position))
	var neighbours := host.get_tree().get_nodes_in_group("npc").filter(func(node):return node is Node2D and node.get("area")==room.area)
	cells = cells.filter(func(c):return neighbours.all(func(node):return Iso.ground_dist(node.global_position,room.area.to_global(HomeData.cell_to_local(Vector2(c))))>=110))
	if cells.is_empty():return false
	var actor := Npc2D.create({"id":"fairy_king","guest":true,"wander":"0","facing":"S"})
	actor.name = "RoyalHomeGuest"
	actor.area = room.area
	actor.position = HomeData.cell_to_local(Vector2(cells[0]))
	room.world.add_child(actor)
	actor.set_guest_home(room.world.to_global(actor.position))
	var ref: WeakRef = weakref(actor)
	var runtime := (SocialManager.get_node("EventDirector") as SocialEventDirector).runner
	var old := runtime.actor_resolver
	var tree := host.get_tree()
	runtime.actor_resolver = func(id: String) -> Node:
		if id=="fairy_king":return ref.get_ref()
		if old.is_valid():return old.call(id)
		return PlayerRegistry.local_player(tree) if id=="player" else NpcDirector.node_of(id)
	var played := await runtime.play(ROYAL,LuaData.dict(Svc.lua_config("home_amenities.royal_scene",{})))
	runtime.actor_resolver = old
	if is_instance_valid(ref.get_ref()):ref.get_ref().queue_free()
	return played
