class_name DungeonEnemyRoster
extends Node
## One 5 Hz proximity pass wakes at most 24 enemies; sleeping actors execute no callbacks.
var enemies: Array = []
var _elapsed: float = 0
static func of(area: IsoArea) -> DungeonEnemyRoster:
	var roster: DungeonEnemyRoster = area.get_node_or_null("EnemyRoster")
	if roster == null:
		roster = DungeonEnemyRoster.new()
		roster.name = "EnemyRoster"
		area.add_child(roster)
	return roster
func register(enemy: Node) -> void:
	if not enemies.any(func(ref): return ref.get_ref() == enemy): enemies.append(weakref(enemy))
func has_room() -> bool:
	return enemies.filter(func(ref): return ref.get_ref() != null and ref.get_ref().state != ref.get_ref().S.DEAD).size() < 48
func _process(dt: float) -> void:
	_elapsed += dt
	if _elapsed < .2: return
	_elapsed = 0
	refresh()
func refresh() -> void:
	var player := PlayerRegistry.local_player(get_tree()) as Node2D
	if player == null: return
	enemies = enemies.filter(func(ref): return ref.get_ref() != null)
	var candidates := []
	for ref in enemies:
		var enemy: Node = ref.get_ref()
		if enemy.state == enemy.S.DEAD: continue
		var distance := Iso.ground_dist(player.global_position,enemy.global_position)
		var was_awake: bool = enemy.process_mode != Node.PROCESS_MODE_DISABLED
		var wake_range := float(enemy.detect)
		if enemy.ambush_state == "hidden": wake_range = maxf(wake_range,780*float(LanternGem.effects(LanternGem.equipped()).ambush_mult))
		var sleep_range := float(enemy.detect)*1.8 if was_awake else 0.0
		if enemy is DungeonBoss2D and enemy.awake:sleep_range = maxf(sleep_range,1800)
		if distance <= maxf(wake_range,sleep_range): candidates.append({"node":enemy,"distance":distance})
	candidates.sort_custom(func(a,b): return a.distance < b.distance)
	var awake := []
	for i in mini(24,candidates.size()): awake.append(candidates[i].node)
	for ref in enemies:
		var enemy: Node = ref.get_ref()
		if enemy.state != enemy.S.DEAD: enemy.set_awake(enemy in awake)
