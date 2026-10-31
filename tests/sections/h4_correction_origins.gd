extends RefCounted
const SECTION := "h4_correction_origins"
const TIMEOUT_S := 180.0
const H1 := preload("res://tests/sections/boss_terminal_origins.gd")

func run(t) -> void:
	await _nested(t)

func _nested(t) -> void:
	if await H1.new()._start(t) == null: return
	GameManager.set_flag(&"forest_mother_version",0)
	var body: Node2D = t.world()._make_player()
	t.world()._register_player(body,1,2)
	t.world().add_child(body)
	body.enter_area(t.world().area,t.player().global_position)
	body.set_physics_process(false)
	var loot: Node = t.autoload("LootService")
	var prior: String = loot.delegate_path
	loot.delegate_path = "res://tests/fixtures/h4_correction_delegate.gd"
	var p0 := PlayerRegistry.peek_state(&"p0")
	PlayerRegistry.for_player(&"p1",func(): EconomyManager.add_item(&"stone",3); EconomyManager.add_gold(100))
	var p1 := PlayerRegistry.peek_state(&"p1")
	var gold: int = p1.gold
	var wood: int = PlayerRegistry.for_player(&"p1",func(): return EconomyManager.count_item(&"wood"))
	var stone: int = PlayerRegistry.for_player(&"p1",func(): return EconomyManager.count_item(&"stone"))
	var entered: Array = []
	var notices: Array = []
	var item := func(pid,id,n):
		if id==&"wood": notices.append(["item",pid,n])
	var money := func(pid,_balance,delta):
		if delta == -3: notices.append(["gold",pid,delta])
	var inventory := func(pid,_pack): notices.append(["inventory",pid])
	EventBus.item_gained.connect(item)
	EventBus.gold_changed.connect(money)
	EventBus.player_inventory_changed.connect(inventory)
	var hook := func(at):
		if at != "commit" or not entered.is_empty(): return
		entered.append(true)
		var unrelated := p0.to_dict().duplicate(true)
		var result: Dictionary = PlayerRegistry.for_player(&"p1",func(): return loot.open_container("skovkant","trae","dg:h4c:inner",{"consume":{"stone":1},"fee":3}))
		entered.append(result.ok and p1.gold==gold-3 and PlayerRegistry.for_player(&"p1",func(): return EconomyManager.count_item(&"wood"))==wood+2 and PlayerRegistry.for_player(&"p1",func(): return EconomyManager.count_item(&"stone"))==stone-1)
		entered.append(p0.to_dict()==unrelated and PlayerRegistry.acting_id()==&"p0")
	Engine.set_meta("h4_delegate_hook",hook)
	var outer: Dictionary = loot.open_container("skovkant","trae","dg:h4c:outer")
	Engine.remove_meta("h4_delegate_hook")
	EventBus.item_gained.disconnect(item)
	EventBus.gold_changed.disconnect(money)
	EventBus.player_inventory_changed.disconnect(inventory)
	t.check("r1_nested_registered_p1_real_commit",entered==[true,true,true] and outer.ok)
	t.check("r1_nested_p1_exact_once_publications",notices.filter(func(row): return row[1]==&"p1")==[["inventory",&"p1"],["gold",&"p1",-3],["inventory",&"p1"],["item",&"p1",2]],str(notices))
	t.check("r1_caller_scope_restored",PlayerRegistry.acting_id()==&"p0")
	loot.delegate_path = prior
	await t.go_menu()
