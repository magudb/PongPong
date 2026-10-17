class_name MotherEvidenceMarker
extends Interactable2D
var evidence_id := ""
var cell := Vector2i.ZERO
var area: IsoArea
var _busy := false
var _leaving := false
var _player: Node
var _screen: Node
var _picture: Sprite2D
var _keepsake: Sprite2D
var _flowers: Array[Sprite2D] = []
var _echo: Sprite2D
const ECHO_IDS := ["traveller_account", "mother_fate"]
func _enter_tree() -> void:
	_leaving = false
	if is_node_ready(): refresh.call_deferred()
func _ready() -> void:
	prompt_key = "FM_INSPECT"
	radius = Vector2(82,48)
	super._ready()
	var row := MotherStory.definition(evidence_id)
	if evidence_id == "marked_lamp": _prop(&"mother_route_map",Vector2(35,5))
	if evidence_id == "mother_fate": _keepsake = _prop(&"mother_seed_tin",Vector2(105,18))
	var art_id := StringName(str(row.get("art","")))
	if ArtCatalog.has_real_prop(art_id):
		_picture = _prop(art_id,Vector2.ZERO)
	if evidence_id in ECHO_IDS:
		_echo = Sprite2D.new()
		_echo.texture = Glow.halo_texture()
		_echo.material = Glow.additive_material()
		_echo.modulate = Color("8fb0e8")
		_echo.scale = Vector2(1.4, 1.4)
		_echo.position = Vector2(0, -52)
		add_child(_echo)
	refresh()
func _prop(id: StringName,at: Vector2) -> Sprite2D:
	var art := ArtCatalog.prop(id)
	var sprite := Sprite2D.new()
	sprite.texture = art.texture
	sprite.centered = false
	sprite.offset = -Vector2(art.pivot)
	sprite.position = at
	add_child(sprite)
	return sprite
func refresh() -> void:
	set_enabled(MotherStory.enabled() and (evidence_id != "legacy_home" or MotherStory.has("mother_fate")))
	if _echo != null: _echo.visible = is_enabled()
	if evidence_id == "echo_account": set_enabled(MotherStory.can_read(evidence_id))
	if _keepsake != null: _keepsake.visible = not MotherStory.has("mother_fate")
	if evidence_id == "legacy_home" and MotherStory.has("legacy_home") and _flowers.is_empty():
		var art := ArtCatalog.prop(&"crop_moonflower_3")
		for index in 3:
			var flower := Sprite2D.new()
			flower.texture = art.texture
			flower.centered = false
			flower.offset = -Vector2(art.pivot)
			flower.position = [Vector2(-100,20),Vector2(100,20),Vector2(0,110)][index]
			add_child(flower)
			_flowers.append(flower)
func _lines() -> Array:
	if evidence_id == "echo_account": return [{"text_key":"FM_FIELD_NOTE"},{"text_key":"FM_E_ECHO_ACCOUNT_TEXT"}]
	if evidence_id == "traveller_account":
		return [{"name_key":"FM_SCRIBE_NAME","text_key":"FM_SCRIBE_TRAVELLER_1"},{"name_key":"FM_SCRIBE_NAME","text_key":"FM_SCRIBE_TRAVELLER_2"},{"text_key":"FM_E_TRAVELLER_ACCOUNT_TEXT"}]
	if evidence_id == "mother_fate":
		return [{"name_key":"FM_SCRIBE_NAME","text_key":"FM_SCRIBE_FINAL_OFFER"},{"text_key":"FM_FINAL_ACCOUNT"},{"text_key":"FM_FINAL_TRUTH"},{"text_key":"FM_FINAL_BARGAIN"}]
	return [{"text_key":"FM_E_"+evidence_id.to_upper()+"_TEXT"}]
func interact(player: Node) -> void:
	if _busy or not is_enabled() or GameManager.is_modal_open(): return
	_screen = LifeFlow.screen(get_tree())
	if _screen == null: return
	_busy = true
	_player = player
	if _player.has_method("begin_talk"): _player.begin_talk(global_position)
	var may_record := MotherStory.can_read(evidence_id)
	var choices: Array = []
	var lines := _lines() if may_record else [{"text_key":MotherStory.next_lead()}]
	if may_record and not MotherStory.has(evidence_id):
		var key := "FM_RECORD"
		if evidence_id == "mother_fate": key = "FM_REFUSE_ROLE"
		elif evidence_id == "legacy_home": key = "FM_PLANT_LEGACY"
		elif evidence_id == "traveller_account": key = "FM_RETURN_NAME"
		choices.append({"text_key":key,"action":"mother_record"})
	choices.append({"text_key":"REL_TALK_GOODBYE","action":"close"})
	var portrait: Texture2D = _picture.texture if _picture != null else null
	var result: Dictionary = await _screen.show_lines({"id":"","name_key":"FM_NAME","portrait":portrait},lines,choices)
	if not _leaving and is_inside_tree() and result.get("completed",false) == true and str(LuaData.dict(result.get("choice",{})).get("action","")) == "mother_record" and may_record:
		MotherStory.record(evidence_id)
		refresh()
	_release()
func _release() -> void:
	# Travel/damage must not clear a newer player state.
	if is_instance_valid(_player) and _player.get("state") == PlayerBody2D.S.TALKING and _player.has_method("end_talk"): _player.end_talk()
	_player = null
	_busy = false
func _exit_tree() -> void:
	_leaving = true
	if _busy and is_instance_valid(_screen): _screen.close()
	_release()
