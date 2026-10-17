class_name Runestone2D
extends Interactable2D
var area: IsoArea
var cell := Vector2i.ZERO
var floor_number := 0
var hub := false
var lit := false
var quest := ""
var objective := ""
var _picture: Node2D
var _busy := false
static func create_marker(params: Dictionary, _pos: Vector2, at: Vector2i, target: IsoArea) -> Node:
	var stone := Runestone2D.new()
	stone.area = target
	stone.cell = at
	stone.hub = str(params.get("hub","0")) == "1"
	stone.floor_number = DungeonFloors.floor_of(target)
	stone.quest = str(params.get("quest",""))
	stone.objective = str(params.get("objective",""))
	stone.prompt_key = "RUNE_PROMPT"
	return stone
func _ready() -> void:
	super._ready()
	add_to_group("runestone")
	refresh()
func refresh() -> void:
	var floors := DungeonFloors.inst()
	lit = hub or (floors != null and floors.stones.has(floor_number))
	if is_instance_valid(_picture): area.remove_prop(_picture)
	_picture = area.place_prop(&"runestone_active" if lit else &"runestone_dormant",cell)
func interact(player: Node) -> void:
	if _busy: return
	var floors := DungeonFloors.inst()
	if floors == null: return
	if hub:
		var ui := get_tree().get_first_node_in_group("game_ui")
		if ui == null: return
		var picker := ui.get_node_or_null("RunePicker")
		if picker == null:
			picker = load("res://scenes/ui/rune_picker.tscn").instantiate()
			picker.name = "RunePicker"
			ui.add_child(picker)
		picker.open()
		return
	_busy = true
	var first := floors.activate_stone(floor_number)
	if player.has_method("heal_full"): player.heal_full()
	if player.has_method("restore_oil"): player.restore_oil()
	refresh()
	if first:
		if quest != "" and objective != "": QuestManager.complete_manual(StringName(quest),StringName(objective))
		SaveManager.autosave()
	EventBus.whisper_requested.emit("RUNE_ACTIVATED" if first else "RUNE_REST")
	_busy = false
