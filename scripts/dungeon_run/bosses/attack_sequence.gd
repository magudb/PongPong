extends Node
var boss: Enemy2D
var rows: Array[Dictionary] = []
var clock: float = 0
func _physics_process(dt: float) -> void:
	if GameManager.is_modal_open():return
	if not is_instance_valid(boss) or boss.state == Enemy2D.S.DEAD:
		queue_free()
		return
	clock += dt
	for row in rows:
		if not row.get("marked",false) and clock >= float(row.delay):
			var ring := TelegraphRing2D.play(boss.area.ground_fx,row.at,{"radius":row.radius,"duration":row.windup,"owner":self})
			if ring == null: continue
			row.marked = true
			row.impact_at = clock+float(row.windup)
			row.ring = weakref(ring)
			row.serial = ring.serial
		if row.get("marked",false) and not row.get("hit",false) and clock >= float(row.impact_at):
			row.hit = true
			var ring: Variant = row.ring.get_ref()
			if ring != null and ring.serial == row.serial: ring.finish()
			if str(row.kind) == "cloud": boss.cloud(row.at)
			else:
				var impact := EnemyHazard2D.new()
				impact.mode = "impact"
				impact.seconds = .2
				impact.radius = float(row.radius)
				impact.damage = 1
				boss.area.ground_fx.add_child(impact)
				impact.global_position = row.at
	if rows.all(func(row): return row.get("hit",false)): queue_free()
func _exit_tree() -> void:
	for row in rows:
		if row.has("ring"):
			var ring: Variant = row.ring.get_ref()
			if ring != null and ring.serial == row.serial: ring.finish()
