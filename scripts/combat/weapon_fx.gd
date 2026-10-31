class_name WeaponFx
extends RefCounted
## Counters belong to the living player, never the save or a shared helper singleton.
static func _info(player: Node, supplied: Variant = null) -> Dictionary:
	if supplied is Dictionary and (supplied.has("effect") or supplied.has("damage")): return supplied
	var combat: Variant = player.get("combat")
	if combat is Object:
		var current: Variant = combat.get("_weapon")
		if current is Dictionary and not current.is_empty(): return current
	var eco := Svc.node("EconomyManager")
	return WeaponInfo.of(eco.equipped_item(&"weapon")) if eco != null else {}
static func _count(player: Node, id: String, action: String) -> int:
	var key := "weapon_"+action+"_"+id
	var value := int(player.get_meta(key,0))+1
	player.set_meta(key,value)
	return value
static func _near(player: Node2D, radius: float) -> Array:
	return player.get_tree().get_nodes_in_group("enemy").filter(func(n): return n is Node2D and Iso.ground_dist(player.global_position,n.global_position) <= radius)
static func _parent(player: Node) -> Node:
	var area: Variant = player.get("area")
	return area.ground_fx if area is IsoArea else player
static func on_swing(player: Node2D, supplied: Variant = null) -> void:
	var info := _info(player,supplied)
	var effect := LuaData.dict(info.get("effect",{}))
	var id := str(effect.get("id",""))
	if id == "": return
	var index := _count(player,str(info.get("id",id)),"swing")
	if supplied is int: index = supplied
	match id:
		"light_arc":
			var radius := 400*float(effect.get("radius_mult",1))
			for enemy in _near(player,radius):
				if enemy.has_method("reveal"): enemy.reveal()
			_pulse(player,radius)
		"reveal_chests":
			EventBus.game_event.emit(&"dungeon_chest_sense_changed",{"cells":int(effect.get("cells",12))})
		"moon_wave","quake":
			if index % maxi(1,int(effect.get("every",4))) != 0: return
			var radius := float(effect.get("range",360)) if id == "moon_wave" else float(effect.get("radius",160))
			var damage := maxi(1,roundi(float(info.get("damage",0))*float(effect.get("mult",.6))))
			var aim := Vector2.RIGHT
			var combat: Variant = player.get("combat")
			# The swing's own direction (a clicked point at press time, the nudge onto an enemy), not a fresh cursor read.
			if combat is Object and combat.has_method("swing_direction"): aim = combat.swing_direction()
			for enemy in _near(player,radius):
				var offset := Iso.to_ground(enemy.global_position-player.global_position)
				if id == "moon_wave" and (offset.dot(aim) < 0 or absf(offset.cross(aim)) > 45): continue
				if enemy.has_method("take_hit"): enemy.take_hit(damage,player.global_position,player)
			_pulse(player,radius)
static func _pulse(player: Node2D, radius: float) -> void:
	var ring := LightRing2D.new()
	ring.setup(radius)
	_parent(player).add_child(ring)
	ring.global_position = player.global_position
	ring.modulate = Color("fbf5e6",.35 if DungeonRun.assist("assist_reduce_flash") else .65)
static func on_hit(player: Node, enemy: Node, supplied: Variant = null) -> void:
	var effect := LuaData.dict(_info(player,supplied).get("effect",{}))
	if str(effect.get("id","")) != "stun_chance" or not enemy.has_method("stun"): return
	if bool(enemy.get("armor")): return
	var chance := clampf(float(effect.get("p",0)),0,1)
	var rng: Variant = enemy.get("rng")
	if chance >= 1 or (rng is RandomNumberGenerator and rng.randf() < chance): enemy.stun(float(effect.get("s",.5)))
static func on_kill(player: Node, _enemy: Node) -> void:
	var info := _info(player)
	var effect := LuaData.dict(info.get("effect",{}))
	match str(effect.get("id","")):
		"oil_on_kill":
			if player.has_method("add_oil"): player.add_oil(float(effect.get("s",2)))
		"heart_on_kill":
			if _count(player,str(info.get("id","heart_on_kill")),"kill") % maxi(1,int(effect.get("every",8))) == 0 and player.has_method("heal_half"):
				player.heal_half(1)
## Inherited kill effects use only the original registered body receipt.
static func on_kill_owned(player: Variant, _enemy: Variant, receipt: Dictionary) -> void:
	if not is_instance_valid(player) or not player is Node or not EventBus.combat_current(receipt): return
	for attached in receipt.bodies:
		if attached.body.get_ref() != player or attached.origin.recipient.player_id != receipt.origin.recipient.player_id: continue
		if not EventBus.interaction_body_current(attached.origin, player, player): return
		var work := func():
			var info := _info(player)
			if not EventBus.combat_current(receipt) or not EventBus.interaction_body_current(attached.origin, player, player): return
			var effect := LuaData.dict(info.get("effect",{}))
			if str(effect.get("id","")) == "oil_on_kill":
				if player.has_method("add_oil_owned"): player.add_oil_owned(float(effect.get("s",2)), receipt, attached.origin)
			elif str(effect.get("id","")) == "heart_on_kill":
				if _count(player,str(info.get("id","heart_on_kill")),"kill") % maxi(1,int(effect.get("every",8))) == 0 and player.has_method("heal_half_owned"):
					player.heal_half_owned(1, receipt, attached.origin)
		PlayerRegistry.for_player(attached.origin.recipient.player_id, work)
		return

static func on_light(player: Node, params: Dictionary) -> Dictionary:
	var result := params.duplicate(true)
	var effect := LuaData.dict(_info(player,result.get("weapon",null)).get("effect",{}))
	if str(effect.get("id","")) == "light_boost":
		result.cooldown = float(result.get("cooldown",7))-float(effect.get("cd_minus_s",0))
		result.radius = float(result.get("radius",550))*float(effect.get("radius_mult",1))
		result.stun = float(result.get("stun",1.6))+float(effect.get("stun_bonus_s",0))
	result.cooldown = maxf(float(Svc.lua_config("dungeon_loot.limits.light_cd_min_s",3)),float(result.get("cooldown",7)))
	return result
static func on_dodge(_player: Node, _supplied: Variant = null) -> void:
	pass
