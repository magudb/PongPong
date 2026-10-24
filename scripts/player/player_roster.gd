class_name PlayerRoster
extends Node
## Per-player profile rows (MP3-player-state). Child of WorldRoot2D, not an autoload (DT-MP6).
##
## Single-player: one row (`p0`) that the EconomyManager / QuestManager / WardrobeManager facades
## read. Shared world state (farm, shops, calendar, home) stays on those managers.
## Save section `players` (RM5, order 15): one JSON row per player slot.

const SECTION := "players"

## player_id -> PlayerState
var rows: Dictionary:
	get: return PlayerRegistry._states
	set(value):
		PlayerRegistry._states = value
		PlayerRegistry._fallback_state = value.get(&"p0", PlayerState.new())


func _ready() -> void:
	name = "PlayerRoster"
	var sm: Node = GameData.autoload("SaveManager")
	if sm != null and sm.has_method("register_section"):
		# Before economy/quests/wardrobe (-40..30): the row is the base, then those facades
		# refine it (stale-item adopt, orphans, routing).
		sm.call("register_section", SECTION, self, -70)


## The row for `player_id`, created on first use.
func state(player_id: StringName = &"p0") -> PlayerState:
	return PlayerRegistry.state(player_id)


## The local hero's row (single-player: the only one).
func local_state() -> PlayerState:
	return state(PlayerRegistry.local_id())


func reset() -> void:
	PlayerRegistry.reset_states()


func to_dict() -> Dictionary:
	var local := local_state()
	var gm := GameData.gm()
	if gm != null:
		local.name = gm.player_name
		local.character_type = gm.character_type
		local.character_skin = gm.character_skin
	var out := {}
	for id in rows:
		out[str(id)] = (rows[id] as PlayerState).to_dict()
	return {"v": 1, "rows": out}


func from_dict(d: Dictionary) -> bool:
	var raw: Variant = d.get("rows")
	if not (raw is Dictionary):
		return false
	var restored := {}
	for key in (raw as Dictionary):
		var row: Variant = (raw as Dictionary)[key]
		if row is Dictionary:
			var st := PlayerState.new()
			if st.from_dict(row as Dictionary):
				restored[st.player_id] = st
	rows = restored
	return true
