extends Node
## Cue names are content ids. AudioManager owns pooling and missing-file silence.
static func rarity_cue(rarity: StringName) -> String:
	return {3:"sfx/loot_rare",4:"sfx/loot_unique",5:"sfx/loot_legendary"}.get(Rarity.rank(rarity),"sfx/pickup_soft")
static func play(cue: String) -> void:
	var audio := Svc.node("AudioManager")
	if audio == null or cue == "": return
	if cue.begins_with("music/"): audio.play_music(cue.trim_prefix("music/"),float(DungeonRun.cfg("audio.music_fade",1)))
	else: audio.play_sfx(cue.trim_prefix("sfx/"))
static func attach(host: Node) -> Node:
	var existing := host.get_node_or_null("DungeonCues")
	if existing != null: return existing
	var node := new()
	node.name = "DungeonCues"
	host.add_child(node)
	return node
func _ready() -> void:
	EventBus.game_event.connect(_event)
	# Bound methods, not lambdas: a lambda that never touches self belongs to the script, so it would outlive this node
	# and every world load would add another set of cues.
	EventBus.item_gained.connect(_item)
	EventBus.whisper_requested.connect(_whisper)
	EventBus.enemy_encountered.connect(_noticed)
	EventBus.player_spawned.connect(_player)
	_player(PlayerRegistry.local_player(get_tree()))
func _item(id: StringName, _amount: int) -> void:
	if DungeonRulesData.player() != null and DungeonFloors.floor_of(DungeonRulesData.player().area) > 0: play(rarity_cue(ItemKinds.rarity_of(id)))
func _whisper(key: String) -> void:
	if key == "DEXP_OIL_LOW": play("sfx/lantern_low")
func _noticed(_id: StringName) -> void:
	play("sfx/enemy_notice")
func _player(node: Node) -> void:
	if not node is Player2D or node.damaged.is_connected(_hurt): return
	node.damaged.connect(_hurt)
func _hurt(_damage: int) -> void:
	play("sfx/hurt_soft")
func _event(id: StringName, data: Dictionary) -> void:
	match id:
		&"audio_cue": play(str(data.get("cue","")))
		&"dungeon_runestone_activated":
			play("sfx/rune_activate")
			play("music/rune_rest")
		&"dungeon_floor_entered":
			play("sfx/hulen_descend")
			play(floor_music(int(data.get("floor",1))))
## Boss floors score the fight (the last one its own track); every other floor plays its act (floors 1-3 = act 1).
static func floor_music(number: int) -> String:
	var floors := DungeonFloors.inst()
	var spec := DungeonSpec.spec_for(floors.cfg,number) if floors != null else {}
	if bool(spec.get("boss",false)):
		return "music/boss_final" if number == int(DungeonRun.cfg("max_floor",12)) else "music/boss"
	return "music/dungeon_act%d" % ceili(number/3.0)
