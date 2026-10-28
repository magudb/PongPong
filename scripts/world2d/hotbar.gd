class_name Hotbar
extends RefCounted
## Eight visible item slots; counts always come from the inventory owner.
signal changed
const SIZE := 8
var slots: Array[StringName] = []
var selected: int = 0
var _body: WeakRef

func bind_body(body: PlayerBody2D) -> void:
	_body = weakref(body)

func _count(item: StringName) -> int:
	if _body == null:
		return int(GameData.eco().count_item(item))
	var body: Node = _body.get_ref()
	var id := PlayerRegistry.registered_id(body)
	return int(PlayerRegistry.for_player(id, func(): return GameData.eco().count_item(item))) if id != &"" else 0

func _init() -> void:
	slots.resize(SIZE)
	slots.fill(&"")

func current() -> StringName:
	return slots[selected]

func select(index: int) -> void:
	if index < 0 or index >= SIZE or index == selected:
		return
	selected = index
	changed.emit()

func cycle(direction: int) -> void:
	select(posmod(selected + direction, SIZE))

func assign(index: int, item: StringName) -> void:
	if item != &"" and GameData.item_def(item).is_empty():
		return
	if index == -1:
		# "Use" from the backpack puts the item in hand: the slot that already holds it, else the first free slot.
		# A full hotbar refuses with a whisper instead of overwriting the selected tool.
		index = slots.find(item)
		if index == -1:
			index = slots.find(&"")
		if index == -1:
			EventBus.whisper_requested.emit("HUD_HOTBAR_FULL")
			return
		if slots[index] == item:
			select(index)
			return
		slots[index] = item
		selected = index
		changed.emit()
		return
	if index < 0 or index >= SIZE or slots[index] == item:
		return
	slots[index] = item
	changed.emit()

func fill_defaults() -> void:
	slots.fill(&"")
	var items := GameData.dict_of(GameData.cfg("starter_kit.tools", {}))
	# Keep authored starter-kit order, with zero-count slots retained after use.
	var index := 0
	for item in items:
		if index == SIZE:
			break
		if _count(StringName(item)) > 0:
			slots[index] = StringName(item)
			index += 1
	changed.emit()

func entries() -> Array:
	var out: Array = []
	for item in slots:
		var def := GameData.item_def(item)
		out.append({"id": String(item), "amount": _count(item),
			"name": str(def.get("name_key", "")), "rare": str(def.get("rarity", "normal"))})
	return out

func to_dict() -> Dictionary:
	return {"slots": slots.map(func(item): return String(item)), "selected": selected}

func from_dict(value: Dictionary) -> void:
	slots.fill(&"")
	var incoming: Variant = value.get("slots", [])
	if incoming is Array:
		for i in mini(incoming.size(), SIZE):
			if incoming[i] is String and not GameData.item_def(StringName(incoming[i])).is_empty():
				slots[i] = StringName(incoming[i])
	var index: Variant = value.get("selected", 0)
	selected = clampi(int(index), 0, SIZE - 1) if index is int or index is float else 0
	changed.emit()
