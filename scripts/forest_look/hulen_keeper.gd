class_name HulenKeeper
extends RefCounted
## The forest freezes the entry hour. Rebuilding on a later visit retries the
## ordinary NPC and all its service/story choices; daytime consumes no topic.
static func create_marker(params: Dictionary, pos: Vector2, cell: Vector2i, area: IsoArea) -> Node:
	var clock := Svc.node("TimeManager")
	if clock != null and clock.is_night():
		return Npc2D.create_marker({"id":str(params.get("npc","mapseller_natteblik")),"wander":"0"},pos,cell,area)
	var sleeper := Interactable2D.new()
	sleeper.name = "SleepingNatteblik"
	sleeper.position = area.objects.to_local(pos)
	sleeper.prompt_key = "LOOK_HULEN_NAME"
	var art := ArtCatalog.prop(&"bat_hang")
	var picture := Sprite2D.new()
	picture.texture = art.texture
	picture.centered = false
	picture.offset = -Vector2(art.pivot)
	sleeper.add_child(picture)
	sleeper.interacted.connect(func(_player: Node): EventBus.whisper_requested.emit("LOOK_NATTEBLIK_SLEEPS"))
	return sleeper
