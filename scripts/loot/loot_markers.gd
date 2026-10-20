class_name LootMarkers
extends RefCounted
## What the three marker handlers of package F4 share (scripts/world2d/loot_chest_2d.gd, dig_spot_2d.gd, unique_spot_2d.gd): the late-bound reach into LootService, the generated-floor
## lookups (DungeonFloors), the whispers of a find, the player's stamina and the sparkle burst. Static and node-free; autoloads only through Svc.

## ground px around a hidden chest within which it shows itself (DUNGEON_V2 8.9: `hidden=1`)
const REVEAL_PX := 240.0
## the stamina one dig costs (order F4 task 4)
const DIG_STAMINA := 4
## the chest sense can reach at most 12 cells (DX31: 96 ground px per cell)
const SENSE_CAP_PX := 12.0 * 96.0
const KEY_FOUND_FMT := "FIND_UI_FOUND_FMT"
const KEY_NOTHING := "FIND_UI_NOTHING"
const KEY_LAKE_LOCKED := "LOOT_LAKE_LOCKED"
const KEY_VAULT_NEEDS := "LOOT_RUNE_VAULT_NEEDS"
const KEY_TIRED := "LOOT_TOO_TIRED"
const KEY_CHEST_RESTING := "LOOT_CHEST_RESTING"
const KEY_DIG_RESTING := "LOOT_DIG_RESTING"
const KEY_SPOT_PACED := "LOOT_SPOT_PACED"
const DUNGEON_RUN_SCRIPT := "res://scripts/dungeon_run/dungeon_run.gd"

## test seam: where DungeonRun.chest_sense_px() is looked up (the contract path; DR1, a later wave)
static var run_script_path: String = DUNGEON_RUN_SCRIPT


static func loot() -> Node:
	return Svc.node("LootService")


## The marker's area id (area.map.id), "" without a map.
static func area_id_of(area: Node) -> String:
	if area == null:
		return ""
	var map: Variant = area.get("map")
	return str((map as Object).get("id")) if map is Object else ""


## The floor number of a generated dungeon area (area.map.extra has `floor`), 0 on a static map.
static func floor_of(area: Node) -> int:
	if area == null:
		return 0
	var map: Variant = area.get("map")
	if not (map is Object):
		return 0
	var extra: Variant = (map as Object).get("extra")
	return LuaData.int_of((extra as Dictionary).get("floor", 0)) if typeof(extra) == TYPE_DICTIONARY else 0


## The DungeonFloors node LootService hosts (null = none): uid_of(area, cell), is_done_cell(area, cell), mark_done_cell(area, cell), band_of(floor).
static func floors() -> Node:
	var l := loot()
	return l.call("floors") as Node if l != null and l.has_method("floors") else null


## {dungeon, floor, band, uid, zone}: how a marker of this area talks to LootService. On a generated floor the uid is DungeonFloors.uid_of(area, cell) and the zone is the
## floor's band; on a static map the uid is area id + ":" + cell and the zone is the area id.
static func context_for(area: Node, cell: Vector2i) -> Dictionary:
	var n := floor_of(area)
	var fl := floors()
	if n > 0 and fl != null:
		var band := str(fl.call("band_of", n))
		return {"dungeon": true, "floor": n, "band": band, "zone": band, "uid": str(fl.call("uid_of", area, cell))}
	var aid := area_id_of(area)
	return {"dungeon": false, "floor": 0, "band": "", "zone": aid, "uid": LootRules.container_uid(aid, cell)}


static func is_done(area: Node, cell: Vector2i, ctx: Dictionary) -> bool:
	var fl := floors()
	return bool(ctx.get("dungeon", false)) and fl != null and bool(fl.call("is_done_cell", area, cell))


static func mark_done(area: Node, cell: Vector2i, ctx: Dictionary) -> void:
	var fl := floors()
	if bool(ctx.get("dungeon", false)) and fl != null:
		fl.call("mark_done_cell", area, cell)


## How far a hidden chest is sensed: the largest of DungeonRun.chest_sense_px() (species, lantern gem and weapon, late bound, 0 without it) and the species perk of the hero
## (SpeciesPerks.chest_sense_px, V1), capped at 12 cells. Never the sum.
static func sense_px() -> float:
	var from_run := float(Svc.static_call(run_script_path, &"chest_sense_px", [], 0))
	var from_species := float(SpeciesPerks.current("chest_sense_px", 0))
	return minf(maxf(from_run, from_species), SENSE_CAP_PX)


## The first node of group `player` (null while none exists).
static func player_of(tree: SceneTree) -> Node2D:
	return PlayerRegistry.local_player(tree) as Node2D if tree != null else null


## Ground distance (px) from a node to the player; INF without a player.
static func player_distance(node: Node2D) -> float:
	var p := player_of(node.get_tree())
	return Iso.ground_dist(node.global_position, p.global_position) if p != null else INF


## Can the player pay `cost` stamina? Player2D.can_spend_stamina(cost) when it has it, else the `stamina` property of the stub; a player without a stamina model always can.
static func has_stamina(player: Node, cost: int) -> bool:
	if player == null:
		return true
	if player.has_method("can_spend_stamina"):
		return bool(player.call("can_spend_stamina", float(cost)))
	var cur: Variant = player.get("stamina")
	return cur == null or float(cur) >= float(cost)


## The player pays `cost` stamina: Player2D.spend_stamina(cost) -> bool when it has it, else the `stamina` property of the stub; a player without a stamina model digs for free.
static func spend_stamina(player: Node, cost: int) -> bool:
	if player == null:
		return true
	if player.has_method("spend_stamina"):
		return bool(player.call("spend_stamina", float(cost)))
	var cur: Variant = player.get("stamina")
	if cur == null:
		return true
	if float(cur) < float(cost):
		return false
	player.set("stamina", float(cur) - float(cost))
	if player.has_signal("stats_changed"):
		player.emit_signal("stats_changed")
	return true


## "Du fandt: A, B x2" - the whisper of a find (the duplicate and keepsake messages come from LootService itself and win: no second whisper over them).
static func whisper_found(res: Dictionary) -> void:
	var rows: Array = res.get("results", [])
	if rows.is_empty():
		EventBus.whisper_requested.emit(KEY_NOTHING)
		return
	if not (res.get("sold", []) as Array).is_empty():
		return
	var names: Array[String] = []
	for row in rows:
		var rd := LuaData.dict(row)
		var id := str(rd.get("id", ""))
		var def := ItemKinds.def(id)
		var shown := String(TranslationServer.translate(StringName(str(def.get("name_key", "ITEM_%s" % id.to_upper())))))
		var n := LuaData.int_of(rd.get("amount", 1), 1)
		names.append("%s x%d" % [shown, n] if n > 1 else shown)
		if Rarity.is_one_of_a_kind(ItemKinds.rarity_of(id)):
			return                                                # LootService whispered the keepsake
	EventBus.whisper_requested.emit(String(TranslationServer.translate(KEY_FOUND_FMT)) % ", ".join(names))


## A one-shot sparkle burst at a global position (soft additive dots rising and fading); frees itself.
static func burst(parent: Node, at: Vector2, color: Color = Color(1.0, 0.96, 0.78), amount: int = 18) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "Burst"
	p.texture = Glow.halo_texture()
	p.material = Glow.additive_material()
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = amount
	p.lifetime = 0.9
	p.direction = Vector2(0, -1)
	p.spread = 80.0
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 130.0
	p.gravity = Vector2(0, 120)
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.14
	p.color = color
	p.z_index = 5
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p
