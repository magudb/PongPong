extends RefCounted
## Own the continuation independently of the picker/actor's scene lifetime.
static func run(npc: String, result: Dictionary, actor: WeakRef) -> void:
	var line := GiftFlow.react(npc, result, false)
	var tree := Engine.get_main_loop() as SceneTree
	var screen := tree.get_first_node_in_group("dialogue_ui") if tree != null else null
	var player := tree.get_first_node_in_group("player") if tree != null else null
	var player_ref: WeakRef = weakref(player) if player != null else null
	var citizen: Node = actor.get_ref() if actor != null else null
	if player != null and citizen != null:
		player.begin_talk(citizen.global_position)
	if screen != null and not line.is_empty():
		await screen.show_lines({"id": npc, "name_key": SocialData.npc_row(npc).get("name_key", "")}, [line], [])
	# Reaction text does not grant another conversation reward.
	citizen = actor.get_ref() if actor != null else null
	if citizen != null:
		citizen.hold(false)
	if player_ref != null and player_ref.get_ref() != null:
		player_ref.get_ref().end_talk()
