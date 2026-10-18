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
	EventBus.item_gained.connect(func(id,_amount):
		if DungeonRulesData.player() != null and DungeonFloors.floor_of(DungeonRulesData.player().area) > 0: play(rarity_cue(ItemKinds.rarity_of(id))))
	EventBus.whisper_requested.connect(func(key):
		if key == "DEXP_OIL_LOW": play("sfx/lantern_low"))
	EventBus.enemy_encountered.connect(func(_id): play("sfx/enemy_notice"))
	EventBus.player_spawned.connect(_player)
	_player(PlayerRegistry.local_player(get_tree()))
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
			var number := int(data.get("floor",1))
			var floors := DungeonFloors.inst()
			var spec := DungeonSpec.spec_for(floors.cfg,number) if floors != null else {}
			play("music/boss_final" if str(spec.get("boss","")) != "" and number == int(DungeonRun.cfg("max_floor",12)) else "music/boss" if str(spec.get("boss","")) != "" else "music/dungeon_act%d" % ceili(number/3.0))
