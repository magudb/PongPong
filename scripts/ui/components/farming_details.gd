extends RefCounted
## Seed information comes from the same definitions used by the live crop model.
static func text(item_id: StringName) -> String:
	var crop := str(GameData.item_def(item_id).get("crop_id", ""))
	var row: Dictionary = FarmGrid.crop_definitions().get(crop, {})
	if row.is_empty(): return ""
	var seasons: Array[String] = []
	for season in row.get("seasons", []):
		seasons.append(str(TranslationServer.translate("UI_SEASON_" + str(season).to_upper())))
	var lines: Array[String] = []
	lines.append(str(TranslationServer.translate("FARMSITE_SEASONS_FMT")) % ", ".join(seasons))
	var nights := int(row.get("stages",4)) * int(row.get("days_per_stage",1))
	lines.append(str(TranslationServer.translate("FARMSITE_GROWTH_FMT")) % nights)
	if int(row.get("regrow_days",0)) > 0:
		lines.append(str(TranslationServer.translate("FARMSITE_REGROW_FMT")) % int(row.regrow_days))
	if not seasons.is_empty() and str(GameManager.season) not in row.get("seasons", []):
		lines.append(str(TranslationServer.translate("FARMSITE_SEEDS_INDOORS")))
	return "\n".join(lines)

static func create(after: Control) -> Label:
	var label := Label.new()
	label.name = "FarmingDetails"
	label.theme_type_variation = &"Muted17"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.hide()
	var parent := after.get_parent()
	parent.add_child(label)
	parent.move_child(label, after.get_index() + 1)
	return label
