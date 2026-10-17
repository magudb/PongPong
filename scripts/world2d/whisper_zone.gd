class_name WhisperZone
extends Area2D
var text_key := ""
var area: IsoArea
var cell := Vector2i.ZERO
var context: Dictionary = {}
var radius_cells: float = 2
var done := false
static func create_marker(params: Dictionary, pos: Vector2, at: Vector2i, target: IsoArea) -> Node:
	var ctx := LootMarkers.context_for(target,at)
	if LootMarkers.is_done(target,at,ctx): return null
	var zone := WhisperZone.new()
	zone.area = target
	zone.cell = at
	zone.context = ctx
	zone.text_key = str(params.get("text",params.get("text_key","")))
	zone.radius_cells = clampf(float(params.get("r",2)),.5,10)
	zone.position = pos
	return zone
func _ready() -> void:
	collision_layer = 0
	collision_mask = Iso.LAYER_PLAYER
	var collision := CollisionShape2D.new()
	var ellipse := ConvexPolygonShape2D.new()
	ellipse.points = Enemy2D._ellipse(Iso.ORTHO_W*radius_cells,Iso.ORTHO_H*radius_cells)
	collision.shape = ellipse
	add_child(collision)
	body_entered.connect(_entered)
func _entered(body: Node) -> void:
	if done or not body.is_in_group("player") or text_key == "": return
	done = true
	LootMarkers.mark_done(area,cell,context)
	EventBus.whisper_requested.emit(text_key)
	set_deferred("monitoring",false)
func set_enabled(on: bool) -> void:
	visible = on
	set_deferred("monitoring",on and not done)
