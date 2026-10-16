extends Control
## Four race cards and two authored heroes per race; the second page retains the player's own names.
signal character_chosen(type: int, skin: StringName, player_name: String)
const CharacterType = preload("res://scripts/autoload/game_manager.gd").CharacterType
const RACES := ["animal", "fairy", "hobbit", "ghost"]
const CARD_NAMES := ["Animal", "Fairy", "Hobbit", "Ghost"]
var selected_type: int = 0
var selected_skin: StringName = &""
var _heroes: Array[Dictionary] = []
var _hero_indices: Dictionary = {}
var _page: int = 1
var _starting := false
var _cards: Array = []
var _chips: Array = []

static func _skins_of(type: int) -> Array:
	var out: Array = []
	for hero in CharacterCatalog.heroes(RACES[clampi(type, 0, 3)]):
		out.append({"id": StringName(hero.skin), "name_key": hero.name_key})
	return out

func _ready() -> void:
	GameManager.change_phase(GameManager.GamePhase.CHARACTER_SELECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	UiNav.watcher()
	var fixtures := preload("res://scripts/ui/dev/ui_fixtures.gd")
	fixtures.register_setup("select2", Callable(get_script(), &"fixture_names"))
	fixtures.register_setup("select_guide4", Callable(get_script(), &"fixture_ghost_guide"))
	_cards = [%AnimalButton, %FairyButton, %HobbitButton, %GhostButton]
	_chips = [%HeroChip1, %HeroChip2]
	for index in _cards.size():
		_cards[index].pressed.connect(_select_type.bind(index))
		_cards[index].focus_entered.connect(_select_type.bind(index))
	for index in _chips.size():
		_chips[index].pressed.connect(_select_hero.bind(index))
		_chips[index].focus_entered.connect(_select_hero.bind(index))
	%NextButton.pressed.connect(func(): _set_page(2))
	%BackButton.pressed.connect(_to_title)
	%BackToRaceButton.pressed.connect(func(): _set_page(1))
	%ConfirmButton.pressed.connect(_on_confirm)
	%NameInput.focus_entered.connect(func(): %NameInput.select_all())
	%FarmNameInput.focus_entered.connect(func(): %FarmNameInput.select_all())
	%NameInput.text_submitted.connect(func(_text: String): %FarmNameInput.grab_focus())
	%FarmNameInput.text_submitted.connect(func(_text: String): %ConfirmButton.grab_focus())
	UiNav.yield_updown_from_fields(self)
	_select_type(0)
	%PreviewName.set_meta(&"tt_text_same_ok", true)
	for chip in _chips:
		chip.get_node("Name").set_meta(&"tt_text_same_ok", true)
	_refresh_texts()
	_set_page(1)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_texts()

func _select_type(index: int) -> void:
	selected_type = index
	_heroes = CharacterCatalog.heroes(RACES[index])
	for card_index in _cards.size():
		var card: Button = _cards[card_index]
		card.button_pressed = card_index == index
		card.position.y = -8.0 if card_index == index else 0.0
	_select_hero(int(_hero_indices.get(index, _default_hero(index))))

func _default_hero(index: int) -> int:
	var skin := CharacterCatalog.default_skin(RACES[index])
	for hero_index in _heroes.size():
		if str(_heroes[hero_index].skin) == skin:
			return hero_index
	return 0

func _select_hero(index: int) -> void:
	if index < 0 or index >= _heroes.size():
		return
	_hero_indices[selected_type] = index
	selected_skin = StringName(_heroes[index].skin)
	for chip_index in _chips.size():
		_chips[chip_index].button_pressed = chip_index == index
	(get_node("%" + CARD_NAMES[selected_type] + "Face") as Control).set("character_id", CharacterCatalog.stock_visual_for_skin(selected_skin, RACES[selected_type]))
	%PreviewFace.character_id = CharacterCatalog.stock_visual_for_skin(selected_skin, RACES[selected_type])
	_refresh_texts()
	_wire()

func _refresh_texts() -> void:
	if not is_node_ready() or _heroes.is_empty():
		return
	%TitleLabel.text = tr("SELECT_TITLE" if _page == 1 else "CHAR_NAME_TITLE")
	%SubtitleLabel.text = tr("CHAR_SELECT_SUBTITLE" if _page == 1 else "CHAR_NAME_SUBTITLE")
	%PageLabel.text = "%d / 2" % _page
	for index in RACES.size():
		var race := CharacterCatalog.race(RACES[index])
		(get_node("%" + CARD_NAMES[index] + "Name") as Label).text = tr(str(race.name_key))
		(get_node("%" + CARD_NAMES[index] + "Perk") as Label).text = tr(str(race.perk_key))
		if index != selected_type:
			(get_node("%" + CARD_NAMES[index] + "Face") as Control).set("character_id", CharacterCatalog.stock_visual_for_skin(CharacterCatalog.default_skin(RACES[index]), RACES[index]))
	for index in _chips.size():
		var hero: Dictionary = _heroes[index]
		var chip: Button = _chips[index]
		(chip.get_node("Name") as Label).text = tr(str(hero.get("chip_name_key", hero.name_key)))
		(chip.get_node("Kind") as Label).text = tr(str(hero.kind_key))
		var width: float = maxf(72.0, chip.get_node("Name").get_minimum_size().x + 32.0)
		if RACES[selected_type] == "ghost":
			width = maxf(width, 78.0 if index == 0 else 102.0)
		chip.custom_minimum_size = Vector2(width, 53)
	var chosen: Dictionary = _heroes[int(_hero_indices.get(selected_type, 0))]
	%HeroBlurb.text = tr(str(chosen.blurb_key))
	%PreviewName.text = tr(str(chosen.name_key))
	%PreviewPerk.text = tr(str(CharacterCatalog.race(RACES[selected_type]).perk_key))
	%NameInput.placeholder_text = tr("DEFAULT_PLAYER_NAME")
	%FarmNameInput.placeholder_text = tr("DEFAULT_FARM_NAME")
	call_deferred("_fit_blurb")

func _fit_blurb() -> void:
	if is_inside_tree():
		%HeroBlurb.offset_left = %Heroes.position.x + %Heroes.get_combined_minimum_size().x + 24.0
		# Preserve the safe right edge and the 12px button gap using the approved theme's real minima.
		var next_width := maxf(164.0, %NextButton.get_combined_minimum_size().x)
		%NextButton.position.x = 1152.0 - next_width
		%NextButton.size.x = next_width
		var back_width := maxf(120.0, %BackButton.get_combined_minimum_size().x)
		%BackButton.position.x = %NextButton.position.x - 12.0 - back_width
		%BackButton.size.x = back_width
		%HeroBlurb.offset_right = (%BackButton.position.x if %BackButton.visible else %NextButton.position.x) - 14.0

func _set_page(page: int) -> void:
	_page = page
	%PageRace.visible = page == 1
	%PageNames.visible = page == 2
	_refresh_texts()
	_wire()
	%HintBar.set_hints([{"pair": [&"ui_left", &"ui_right"], "key": "HINT_MOVE"}, {"action": &"ui_accept", "key": "HINT_NEXT" if page == 1 else "HINT_START"}, {"action": &"ui_cancel", "key": "HINT_BACK"}])
	await get_tree().process_frame
	if page == _page and is_inside_tree():
		(_cards[selected_type] if page == 1 else %NameInput).grab_focus()

func _wire() -> void:
	if not is_node_ready():
		return
	if _page == 1:
		UiNav.wire_row(_cards)
		var bottom: Array = _chips + [%BackButton, %NextButton]
		UiNav.wire_row(bottom)
		UiNav.wire_groups([_cards, bottom])
		var chip: Button = _chips[int(_hero_indices.get(selected_type, 0))]
		for card in _cards:
			UiNav.link(card, &"up", chip)
			UiNav.link(card, &"down", chip)
		for control in bottom:
			UiNav.link(control, &"up", _cards[selected_type])
			UiNav.link(control, &"down", _cards[selected_type])
	else:
		UiNav.wire_ring([%NameInput, %FarmNameInput, %BackToRaceButton, %ConfirmButton])
		UiNav.wire_row([%BackToRaceButton, %ConfirmButton])
		UiNav.link(%NameInput, &"down", %FarmNameInput)
		UiNav.link(%NameInput, &"up", %ConfirmButton)
		UiNav.link(%FarmNameInput, &"up", %NameInput)
		UiNav.link(%FarmNameInput, &"down", %ConfirmButton)
		for button in [%BackToRaceButton, %ConfirmButton]:
			UiNav.link(button, &"up", %FarmNameInput)
			UiNav.link(button, &"down", %NameInput)
		var tab: Array = [%NameInput, %FarmNameInput, %BackToRaceButton, %ConfirmButton]
		for index in tab.size():
			tab[index].focus_next = tab[index].get_path_to(tab[(index + 1) % tab.size()])
			tab[index].focus_previous = tab[index].get_path_to(tab[posmod(index - 1, tab.size())])

func _input(event: InputEvent) -> void:
	var vp := get_viewport()
	if _starting or vp == null:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if _page == 2:
			_set_page(1)
		else:
			_to_title()
		vp.set_input_as_handled()
	elif event.is_action_pressed("ui_page_up"):
		if _page == 2:
			_set_page(1)
		else:
			_to_title()
		vp.set_input_as_handled()
	elif event.is_action_pressed("ui_page_down") and _page == 1:
		_set_page(2)
		vp.set_input_as_handled()
	elif _page == 1 and event.is_action_pressed("ui_accept") and vp.gui_get_focus_owner() in _cards:
		_set_page(2)
		vp.set_input_as_handled()
	elif not UiNav.text_field_focused(vp):
		UiNav.wasd_translate(vp, event)

func _to_title() -> void:
	UiNav.remember(&"title", "NewGameButton")
	get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")

func _on_confirm() -> void:
	if _starting:
		return
	_starting = true
	var player: String = %NameInput.text.strip_edges()
	var farm: String = %FarmNameInput.text.strip_edges()
	if player == "":
		player = tr("DEFAULT_PLAYER_NAME")
	if farm == "":
		farm = tr("DEFAULT_FARM_NAME")
	character_chosen.emit(selected_type, selected_skin, player)
	GameManager.start_new_game(player, selected_type, farm, selected_skin)
	get_tree().change_scene_to_file("res://scenes/main/world.tscn")

static func fixture_names(node: Node, _host: Node) -> void:
	await node.call("_set_page", 2)

static func fixture_ghost_guide(node: Node, _host: Node) -> void:
	node.call("_select_type", 3)
	await node.call("_set_page", 1)
	preload("res://scripts/ui/dev/ui_fixtures.gd").apply_guide_rules("select_guide", node)
	node.call("_fit_blurb")
