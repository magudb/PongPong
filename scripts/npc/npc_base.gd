extends Node3D
## NPC with dialogue, quests, and shop interactions.

@export var npc_id: StringName = &""
@export var display_name_key: String = ""
@export var dialogue_id: StringName = &""
@export var shop_id: StringName = &""
@export var offers_quests: Array[StringName] = []

var is_talking: bool = false


func _ready() -> void:
	add_to_group("npc")
	# Visual placeholder
	_create_placeholder_visual()


func _create_placeholder_visual() -> void:
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.height = 1.4
	capsule.radius = 0.35
	mesh.mesh = capsule
	mesh.position.y = 0.7

	var mat := StandardMaterial3D.new()
	mat.albedo_color = _npc_color()
	mesh.material_override = mat

	var body := StaticBody3D.new()
	body.collision_layer = 4  # npc
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.height = 1.4
	shape.radius = 0.35
	col.shape = shape
	body.add_child(col)

	# Name label
	var label := Label3D.new()
	label.text = tr(display_name_key) if display_name_key != "" else str(npc_id)
	label.position.y = 1.8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED

	mesh.add_child(body)
	mesh.add_child(label)
	add_child(mesh)


func _npc_color() -> Color:
	match npc_id:
		&"mayor_lyra":
			return Color(0.8, 0.7, 0.9)
		&"baker_maja":
			return Color(0.9, 0.75, 0.55)
		&"fairy_lily":
			return Color(0.95, 0.8, 0.85)
		&"smith_thorin":
			return Color(0.6, 0.5, 0.4)
	return Color(0.7, 0.7, 0.7)


func get_interaction_prompt() -> String:
	return tr("UI_TALK") if display_name_key != "" else str(npc_id)


func interact(player: Node3D) -> void:
	if is_talking:
		return
	is_talking = true

	# Build context for Lua dialogue — all world flags plus defaults
	var context := GameManager.world_flags.duplicate()
	context["intro_done"] = context.get("intro_done", false)
	context["maja_roof_fixed"] = context.get("maja_roof_fixed", false)
	context["lost_cat_active"] = context.get("lost_cat_active", false)

	var dialogue: Dictionary = LuaRuntime.get_dialogue(str(dialogue_id), context)
	if dialogue.is_empty():
		is_talking = false
		return

	EventBus.dialogue_started.emit(npc_id, dialogue_id)
	_show_dialogue(dialogue)


func _show_dialogue(dialogue: Dictionary) -> void:
	var speaker_name: String = tr(dialogue.get("speaker_name_key", str(npc_id)))

	for line in dialogue.get("lines", []):
		var text_key: String = line.get("text_key", "")
		var voice_key: String = line.get("voice_key", "")
		var text: String = tr(text_key) if text_key != "" else ""

		EventBus.dialogue_line_shown.emit(speaker_name, text, voice_key)
		if voice_key != "":
			LocalizationManager.play_voice(str(npc_id), voice_key)

		# Wait for player to advance (simplified — real impl uses input)
		await get_tree().create_timer(2.5).timeout

	# Show choices via UI
	var choices: Array = dialogue.get("choices", [])
	if not choices.is_empty():
		EventBus.ui_panel_toggled.emit(&"dialogue_choices", true)
		# Choice handling is done by DialogueUI

	EventBus.dialogue_ended.emit()
	is_talking = false


func handle_choice(action: String, data: Dictionary = {}) -> void:
	match action:
		"quest_accept":
			QuestManager.accept_quest(StringName(data.get("quest_id", "")))
		"quest_offer":
			QuestManager.offer_quest(StringName(data.get("quest_id", "")))
		"open_shop":
			ShopSystem.open_shop(StringName(data.get("shop_id", "")))
		"open_journal":
			EventBus.ui_panel_toggled.emit(&"journal", true)
		"close":
			pass
		"show_info":
			EventBus.notification_posted.emit(
				tr("UI_INFO"),
				tr(data.get("info_key", "")),
				"info"
			)
		"math_answer":
			if int(data.get("answer", -9999)) == int(data.get("correct", -1)):
				var flag := StringName(data.get("result_flag", ""))
				if flag != &"":
					GameManager.set_flag(flag, true)
				var quest_id := StringName(data.get("quest_id", ""))
				var objective_id := StringName(data.get("objective_id", ""))
				if quest_id != &"" and objective_id != &"":
					QuestManager.update_objective(quest_id, objective_id)
				EventBus.notification_posted.emit(tr("MATH_CORRECT_TITLE"), tr("MATH_CORRECT_MSG"), "success")
			else:
				EventBus.notification_posted.emit(tr("MATH_WRONG_TITLE"), tr("MATH_WRONG_MSG"), "info")
