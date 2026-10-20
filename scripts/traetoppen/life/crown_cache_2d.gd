class_name CrownCache2D
extends Interactable2D
## Small normal loot only; deliberately never enters the rarity/quest loot service.
var slot := 0
var _busy := false
static func create_marker(params: Dictionary, _pos: Vector2, _cell: Vector2i, _area: IsoArea) -> Node:
	var cache := CrownCache2D.new()
	cache.slot = int(params.get("slot", 0))
	cache.prompt_key = "LIFE_CACHE_PROMPT"
	return cache
func _ready() -> void:
	super._ready()
	refresh()
func _enter_tree() -> void:
	EventBus.day_started.connect(_morning)
func _exit_tree() -> void:
	if EventBus.day_started.is_connected(_morning):
		EventBus.day_started.disconnect(_morning)
func _morning(_day: int, _season: StringName) -> void:
	refresh()
func eligible() -> bool:
	return bool(SpeciesPerks.current("crown_caches", false)) and GameManager.flag_int(&"cache_day") != GameManager.total_day() and slot == posmod(GameManager.total_day(), maxi(1, int(GameManager.config_value("traetoppen.caches.slots", 5))))
func refresh() -> void:
	set_enabled(eligible())
	queue_redraw()
func _process(_delta: float) -> void:
	var player := PlayerRegistry.local_player(get_tree()) as Node2D
	visible = is_enabled() and player != null and Iso.to_ground(player.global_position - global_position).length() <= float(SpeciesPerks.current("chest_sense_px", 0))
func _draw() -> void:
	if visible:
		var color := Color("d6a84b")
		draw_line(Vector2(-12, 0), Vector2(12, 0), color, 3)
		draw_line(Vector2(0, -12), Vector2(0, 12), color, 3)
func interact(_player: Node) -> void:
	if _busy or not eligible():
		return
	var items := LuaData.arr(GameManager.config_value("traetoppen.caches.items", ["wild_flower", "apple", "fern", "friendship_token"]))
	if items.is_empty():
		return
	var item := StringName(str(items.pick_random()))
	if not EconomyManager.can_add_item(item):
		EventBus.whisper_requested.emit("LIFE_BAG_FULL")
		return
	_busy = true
	var low := maxi(0, int(GameManager.config_value("traetoppen.caches.gold_min", 20)))
	var high := maxi(low, int(GameManager.config_value("traetoppen.caches.gold_max", 50)))
	EconomyManager.defer_notifications(func():
		GameManager.set_flag(&"cache_day", GameManager.total_day())
		refresh()
		EconomyManager.add_item(item, 1, true)
		EconomyManager.add_gold(randi_range(low, high)))
	EventBus.whisper_requested.emit("LIFE_CACHE_DONE")
	_busy = false
