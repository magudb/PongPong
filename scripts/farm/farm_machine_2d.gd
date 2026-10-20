class_name FarmMachine2D
extends Interactable2D
var area: IsoArea
var cell: Vector2i
var picture: Node2D
var _busy := false
var _ready_icon: Sprite2D

func _ready() -> void:
	super._ready()
	EventBus.day_started.connect(func(_day, _season): refresh.call_deferred())
	refresh()

func get_interaction_prompt() -> String:
	var piece := FarmEquipment.at(area.map.id, cell)
	var batch: Dictionary = piece.get("batch", {})
	if not batch.is_empty():
		if GameManager.total_day() >= int(batch.ready_day):
			return tr("FARMSITE_MACHINE_READY_FMT") % tr(str(GameData.item_def(StringName(str(batch.output))).get("name_key", "")))
		return tr("FARMSITE_MACHINE_BUSY_FMT") % (int(batch.ready_day) - GameManager.total_day())
	return tr("FARMSITE_MACHINE_PICKUP") if FarmEquipment.spec(StringName(str(piece.get("item", "")))).has("offsets") else tr("FARMSITE_MACHINE_LOAD")

func interact(player: Node) -> void:
	if _busy or not is_enabled(): return
	var piece := FarmEquipment.at(area.map.id, cell)
	var batch: Dictionary = piece.get("batch", {})
	_busy = true
	if not batch.is_empty():
		if GameManager.total_day() >= int(batch.ready_day) and not FarmEquipment.collect(piece):
			EventBus.whisper_requested.emit("KISTE_FULL")
	elif FarmEquipment.spec(StringName(str(piece.get("item", "")))).has("offsets"):
		EventBus.whisper_requested.emit("FARMSITE_MACHINE_PICKUP")
	elif not player is Player2D or not FarmEquipment.load_crop(piece, player.hotbar.current()):
		EventBus.whisper_requested.emit("FARMSITE_MACHINE_CROP_ONLY")
	_busy = false
	refresh()

## The tool contract (Player2D._takes_tool): the axe and the pickaxe both pick a machine up.
func accepts_tool(tool: String) -> bool:
	return not _busy and tool in ["axe", "pickaxe"]

func tool_hit(tool: String, _power: int, _player: Node) -> bool:
	if _busy or tool not in ["axe", "pickaxe"]: return false
	var piece := FarmEquipment.at(area.map.id, cell)
	if piece.has("batch"):
		EventBus.whisper_requested.emit("FARMSITE_MACHINE_PICKUP_BUSY")
		return false
	_busy = true
	var ok := FarmEquipment.pickup(area, cell, picture)
	if not ok: _busy = false
	return ok

func refresh() -> void:
	var piece := FarmEquipment.at(area.map.id, cell)
	var batch: Dictionary = piece.get("batch", {})
	if _ready_icon == null:
		_ready_icon = Sprite2D.new()
		_ready_icon.position = Vector2(0,-110)
		_ready_icon.scale = Vector2.ONE * 0.45
		add_child(_ready_icon)
	_ready_icon.visible = not batch.is_empty() and GameManager.total_day() >= int(batch.ready_day)
	if _ready_icon.visible:
		_ready_icon.texture = ArtCatalog.icon(StringName(str(batch.output)))
