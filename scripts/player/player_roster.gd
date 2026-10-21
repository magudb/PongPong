class_name PlayerRoster
extends Node
## Per-player profile rows (MP3-player-state). Child of WorldRoot2D, not an autoload (DT-MP6).
##
## Single-player: one row (`p0`) that the EconomyManager / QuestManager / WardrobeManager facades
## read. Shared world state (farm, shops, calendar, home) stays on those managers.

## player_id -> PlayerState
var rows: Dictionary = {}


func _ready() -> void:
	name = "PlayerRoster"


## The row for `player_id`, created on first use.
func state(player_id: StringName = &"p0") -> PlayerState:
	if not rows.has(player_id):
		rows[player_id] = PlayerState.new(player_id, 1 if player_id == &"p0" else int(str(player_id).trim_prefix("p")) + 1)
	return rows[player_id]


## The local hero's row (single-player: the only one).
func local_state() -> PlayerState:
	return state(PlayerRegistry.local_id())


func reset() -> void:
	rows.clear()
	# Adopt the shared fallback row: managers may already have written their new-game
	# state into it before the world scene exists. Do not wipe it here.
	rows[&"p0"] = PlayerRegistry._fallback_state


func to_dict() -> Dictionary:
	var out := {}
	for id in rows:
		out[str(id)] = (rows[id] as PlayerState).to_dict()
	return {"v": 1, "rows": out}


func from_dict(d: Dictionary) -> bool:
	rows.clear()
	var raw: Variant = d.get("rows")
	if not (raw is Dictionary):
		return false
	for key in (raw as Dictionary):
		var row: Variant = (raw as Dictionary)[key]
		if row is Dictionary:
			var st := PlayerState.new()
			if st.from_dict(row as Dictionary):
				rows[st.player_id] = st
	return true
