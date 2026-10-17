extends RefCounted
const SECTION := "dungeon_items"
const PRICES := {"dng_resin":2,"dng_mushroom_felt":2,"dng_forest_thread":1,"dng_forest_steel":10,"dng_glimmer_dust":8,"dng_owl_feather":6,"dng_moon_silver":24,"dng_crystal_root":21}
func run(t) -> void:
	var lr: Node = t.autoload("LuaRuntime")
	var ids := []
	for id in ItemKinds.all_ids():
		if str(id) == "gem_bag": continue
		if str(id).begins_with("wpn_") or str(id).begins_with("gem_") or str(id).begins_with("rough_") or str(id).begins_with("dng_"): ids.append(str(id))
	t.check("ids_load_51",ids.size() == 51,str(ids.size()))
	var sword := {"normal":5,"uncommon":12,"rare":22,"unique":30,"legendary":42}
	var families := {"sword":1.0,"dagger":.65,"club":1.35,"spear":1.08,"staff":1.125}
	for id in ids:
		var row := ItemKinds.def(id)
		t.check("complete_"+id,row.has("category") and row.has("rarity") and row.has("max_stack") and row.has("buy_price") and row.has("sell_price"))
		if Rarity.is_one_of_a_kind(row.rarity):
			t.check("protected_"+id,int(row.buy_price) == 0 and int(row.sell_price) == 0 and row.has("hint_key") and row.get("protected",false))
		elif int(row.buy_price) > 0:
			t.check("sell_below_half_"+id,int(row.sell_price) < float(row.buy_price)/2)
		if str(row.category) == "weapon":
			t.check("damage_formula_"+id,absf(float(row.damage)-float(sword[row.rarity])*float(families[row.weapon_family])) <= .5)
		for locale in ["da","en"]:
			TranslationServer.set_locale(locale)
			for field in ["name_key","description_key"]:
				var key := str(row.get(field,""))
				t.check("text_%s_%s_%s" % [id,locale,field],key != "" and TranslationServer.translate(key) != key)
	TranslationServer.set_locale("da")
	for id in PRICES:
		var row := ItemKinds.def(id)
		t.check("dng_material_price_"+id,int(row.sell_price) == PRICES[id] and int(row.sell_price) <= float(row.buy_price)*.25)
	var recipes: Dictionary = lr.get_recipes()
	var count := 0
	for id in recipes:
		if not str(id).begins_with("dng_forge_"): continue
		count += 1
		var recipe: Dictionary = recipes[id]
		var output := ItemKinds.def(recipe.output.item)
		t.check("recipe_output_"+str(id),not Rarity.is_one_of_a_kind(output.rarity) and str(recipe.station) in ["smedje","snedkerbord"])
		for multiplier in [2.0,2.2,2.5]:
			var cost := 0.0
			for ingredient in recipe.ingredients:
				var row := ItemKinds.def(ingredient)
				cost += float(recipe.ingredients[ingredient])*(float(row.buy_price) if int(row.buy_price) > 0 else multiplier*float(row.sell_price))
			t.check("recipe_band_%s_%s" % [id,multiplier],cost >= float(output.buy_price)*.45 and cost <= float(output.buy_price)*.85 and cost > float(output.sell_price),str(cost))
	t.check("thirteen_recipes",count == 13)
	var shards := ids.filter(func(id): return str(id).begins_with("dng_rune_"))
	t.check("rune_shards_are_three",shards.size() == 3)
