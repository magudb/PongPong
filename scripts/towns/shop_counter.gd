class_name ShopCounter
extends Interactable2D
## The hosts of a counter band (T-towns-core, TOWNS addendum 4.4 / SE1 / SE2): the markers `shop`, `post_counter`, `bar`, `appraisal`, `desk` and `talk` of a room JSON. ONE rule,
## decided by where the player STANDS: the built E-query (PlayerStub2D.nearest_interactable, Player2D keeps the rule) takes, among the hosts whose ellipse overlaps the circle r = 45 at the
## facing cell, the host NEAREST TO THE PLAYER. The middle cell of the band selects the centre host, an end cell the `talk` host of that cell.
##   shop          counter middle (150 x 40)   -> ShopSystem.open_shop(shop_id): the guide's panel over the live (blurred) room
##   post_counter  counter middle              -> game_event open_post_office {npc, building}
##   bar           counter middle              -> game_event open_inn_menu {npc, building}
##   appraisal     counter middle (Uglehulen)  -> game_event open_appraisal {npc, building} (design2's event, F4's LootService hosts the screen); refused with the whisper of the
##                                                hours while the building is closed, and with COUNTER_APPRAISE_SOON while LootService has no appraise() yet
##   desk          builder yard only (40 x 22) -> game_event open_home_builder {tier = the world flag home_tier}: the second door of the Husbyggeri
##   talk          the two cells in front of the counter ENDS (40 x 22) -> the keeper's own Npc2D.interact(player): greeting, weekly heart, gifts, topics, quests; DISABLED (inert and
##                 invisible to the E-query) until a keeper node stands in the room (polled every 0.5 s and on game_event area_populated)
## There is NO forward_to_keeper seam and NO gift shortcut (SE1): the old rule "a giftable hotbar item takes E first" would have sent every tool and seed into a gift talk instead of the panel.
## The markers bath / board / mailbox belong to V6's own classes (BathTub2D, NoticeBoard2D, PostBox2D) through IsoArea.resolve_handler; until a handler exists the room builds this class
## with that kind as a fallback counter that only announces the use as game_event counter_used {npc, building, kind}.

const _Svc := preload("res://scripts/data/svc.gd")
## The room director of T-routes (wave 5): a path string, never a class name (TE1).
const DIRECTOR := "res://scripts/towns/npc_director.gd"
const LOOT_SERVICE := "LootService"
const HALF_AXES := {"shop": Vector2(150, 40), "post_counter": Vector2(150, 40), "bar": Vector2(150, 40), "appraisal": Vector2(150, 40), "bath": Vector2(150, 40), "board": Vector2(150, 40),
		"desk": Vector2(40, 22), "talk": Vector2(40, 22), "mailbox": Vector2(60, 30)}
const PROMPTS := {"shop": "COUNTER_SHOP", "post_counter": "COUNTER_SHOP", "bar": "COUNTER_SHOP", "appraisal": "COUNTER_APPRAISE", "desk": "COUNTER_DESK", "talk": "COUNTER_TALK"}
const EVENTS := {"post_counter": &"open_post_office", "bar": &"open_inn_menu"}
## The six kinds of the contract; any other kind is the fallback of a handler marker.
const KINDS: Array[String] = ["shop", "post_counter", "bar", "appraisal", "desk", "talk"]

## Tests inject the live keeper of a room here (Callable(keeper_id: String) -> Node); the default asks NpcDirector.node_of through its path.
static var keeper_resolver: Callable = Callable()

var kind: String = "shop"
var shop_id: String = ""
var keeper_id: String = ""
var building_id: String = ""

var _timer: Timer


## kind: one of KINDS (or a handler marker kind), marker: the room JSON marker {id?, keeper?}, building: the building id of the room.
func setup(p_kind: String, marker: Dictionary, building: String) -> void:
	kind = p_kind
	shop_id = str(marker.get("id", ""))
	keeper_id = str(marker.get("keeper", ""))
	building_id = building
	radius = HALF_AXES.get(kind, Vector2(150, 40)) as Vector2
	prompt_key = str(PROMPTS.get(kind, "WORLD_PROMPT_USE"))
	name = "Counter_%s" % kind


func _ready() -> void:
	super._ready()
	# Counter choice follows the customer's cell, including when their feet
	# already occupy the small talk host and they face the counter beyond it.
	set_meta("counter_foot_host", true)
	if kind == "talk":
		set_enabled(false)                                  # inert and invisible to the E-query until a keeper node stands in the room
		_timer = Timer.new()
		_timer.wait_time = 0.5
		_timer.timeout.connect(_refresh)
		add_child(_timer)
		_timer.start()
		EventBus.game_event.connect(_on_game_event)
		_refresh()


func _exit_tree() -> void:
	if kind == "talk" and EventBus.game_event.is_connected(_on_game_event):
		EventBus.game_event.disconnect(_on_game_event)


func _on_game_event(event_name: StringName, _payload: Dictionary) -> void:
	if event_name == &"area_populated":
		_refresh()


## A talk host is enabled exactly while the keeper's node stands in the room.
func _refresh() -> void:
	set_enabled(keeper_node() != null)


## The live keeper node of the room (NpcDirector.node_of late bound, or the test resolver), or null.
func keeper_node() -> Node:
	var v: Variant = null
	if keeper_resolver.is_valid():
		v = keeper_resolver.call(keeper_id)
	else:
		var room: Node = get_parent()
		while room != null and not (room is IsoArea):
			room = room.get_parent()
		v = _Svc.static_call(DIRECTOR, &"node_of", [keeper_id, room], null)
	return v as Node if v is Node and is_instance_valid(v) else null


func get_interaction_prompt() -> String:
	if kind == "talk":
		return tr(prompt_key) % tr("NPC_%s" % keeper_id.to_upper())
	return tr(prompt_key) if prompt_key != "" else ""


func interact(player: Node) -> void:
	if not is_enabled():
		return
	interacted.emit(player)
	match kind:
		"talk":
			var k: Node = keeper_node()
			if k != null and k.has_method("interact"):
				k.call("interact", player)
		"shop":
			var sys: Node = _Svc.node("ShopSystem")
			if sys != null:
				sys.call("open_shop", shop_id)
		"appraisal":
			if _closed_whisper():
				return
			var loot: Node = _Svc.node(LOOT_SERVICE)
			if loot == null or not loot.has_method("appraise"):
				EventBus.whisper_requested.emit("COUNTER_APPRAISE_SOON")
				return
			EventBus.game_event.emit(&"open_appraisal", {"npc": keeper_id, "building": building_id})
		"desk":
			var gm: Node = GameData.gm()
			EventBus.game_event.emit(&"open_home_builder", {"tier": int(gm.call("flag_int", &"home_tier", 1)) if gm != null else 1})
		"post_counter", "bar":
			EventBus.game_event.emit(EVENTS[kind], {"npc": keeper_id, "building": building_id})
		_:
			EventBus.game_event.emit(&"counter_used", {"npc": keeper_id, "building": building_id, "kind": kind})


## true (and the whisper of the reason) when the building's hours say closed right now: the appraisal is refused while the room is closed (the door and the eviction normally prevent
## being here at all). Off with the switch towns.hours_enabled.
func _closed_whisper() -> bool:
	if building_id == "" or not Hours.enabled():
		return false
	var st: Dictionary = Hours.state(building_id)
	if bool(st["open"]):
		return false
	EventBus.whisper_requested.emit(Hours.closed_text(st))
	return true
