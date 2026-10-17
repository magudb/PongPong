extends RefCounted
## Presentation reads the same weapon/gem rules used by real combat.
static func text(id: String) -> String:
	var lines: Array[String] = []
	var weapon := WeaponInfo.of(id)
	if not weapon.is_empty():
		lines.append("%s %d · %s %.1f · %s %.1f" % [TranslationServer.translate("WSTAT_DAMAGE"),int(weapon.damage),TranslationServer.translate("WSTAT_SPEED"),1.0/float(weapon.cycle),TranslationServer.translate("WSTAT_RATING"),float(weapon.rating)])
		var floors := DungeonRun.weapon_range(id)
		lines.append("%s · %s" % [TranslationServer.translate("WEAPON_FAMILY_"+str(weapon.family).to_upper()),TranslationServer.translate("DEXP_WEAPON_RANGE_FMT") % [floors.x,floors.y]])
		var effect := LuaData.dict(weapon.effect)
		var key := "WEFFECT_"+str(effect.get("id","")).to_upper()
		match str(effect.get("id","")):
			"stun_chance":lines.append(TranslationServer.translate(key) % [roundi(float(effect.p)*100),float(effect.s)])
			"oil_on_kill":lines.append(TranslationServer.translate(key) % int(effect.s))
			"heart_on_kill","moon_wave","quake":lines.append(TranslationServer.translate(key) % int(effect.every))
			"light_arc":lines.append(TranslationServer.translate(key))
			"reveal_chests":lines.append(TranslationServer.translate(key) % int(effect.cells))
			"light_boost":lines.append(TranslationServer.translate(key) % [float(effect.cd_minus_s),roundi((float(effect.radius_mult)-1)*100)])
	elif LanternGem.can_equip(id):
		var gem := LanternGem.effects(id)
		if float(gem.oil_mult)<1:lines.append(TranslationServer.translate("GEMFX_OIL") % roundi((1-float(gem.oil_mult))*100))
		if float(gem.radius_mult)>1:lines.append(TranslationServer.translate("GEMFX_RADIUS") % roundi((float(gem.radius_mult)-1)*100))
		if float(gem.light_cd_minus_s)>0:lines.append(TranslationServer.translate("GEMFX_LIGHT_CD") % float(gem.light_cd_minus_s))
		if int(gem.chest_sense_cells)>0:lines.append(TranslationServer.translate("GEMFX_CHEST_SENSE") % int(gem.chest_sense_cells))
		if float(gem.ambush_mult)>1:lines.append(TranslationServer.translate("GEMFX_AMBUSH") % roundi((float(gem.ambush_mult)-1)*100))
		if float(gem.pickup_mult)>1:lines.append(TranslationServer.translate("GEMFX_PICKUP") % roundi((float(gem.pickup_mult)-1)*100))
		if lines.is_empty():lines.append(TranslationServer.translate("GEMFX_TINT_ONLY"))
	return "\n".join(lines)
