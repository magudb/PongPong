extends VBoxContainer
## One ability button of the forest HUD (guide section 10): frame with gold double ring, dark cooldown veil rising
## from the bottom, cooldown seconds in Caprasimo, and the key cap below ("Venstre klik", "Mellemrum", "Q", "R").
## The icon draws item art (TTItemIcon: items, home, wardrobe) so the four slots read at a glance on a dark floor: ART names the
## picture of each ability (sword, boots, fairy dust, red tonic) until abilities get art of their own; any other id looks up
## <id>.webp itself. Without a picture the frame shows the ability's Danish word in tiny mono like the guide mock ("slag", "undvig",
## "fe-lys", "drik"): the text of the key ABILITY_<ID> (ABILITY_SLASH, ...; forest.csv, owner P19). The icon id itself ('slash')
## is English and technical, so it is NEVER shown: while ABILITY_<ID> has no translation the slot shows the icon only (the picture
## when there is one, else an empty frame).
## setup() and set_cooldown() may be called before the slot is in the tree (the forest HUD builds its four slots instantiate ->
## setup -> add_child): the data is kept and applied in `_ready`. The word and the key cap follow a language switch.

## ability id -> the item art drawn for it (UX-19: the words alone were unreadable mid-fight).
const ART := {&"slash": &"iron_sword", &"dodge": &"shoes_boots_wind", &"light": &"fairy_dust", &"drink": &"health_tonic"}

@onready var frame: Control = %Frame
@onready var icon = %Icon
@onready var veil: ColorRect = %Veil
@onready var cd_label: Label = %CooldownLabel
@onready var key_label: Label = %KeyLabel

var action: StringName = &""
var icon_id: StringName = &""

var _side := 64.0
var _setup_pending := false
var _cd_fraction := 0.0
var _cd_text := ""


func _ready() -> void:
	if _setup_pending:
		_setup_pending = false
		_apply_setup()
	_apply_cooldown()


## icon_id is the ability id (slash, dodge, light, drink). size: 78 for the primary attack, 64 for the others.
func setup(p_icon_id: StringName, p_action: StringName, side: float = 64.0) -> void:
	icon_id = p_icon_id
	action = p_action
	_side = side
	_cd_fraction = 0.0
	_cd_text = ""
	if not is_node_ready():
		_setup_pending = true
		return
	_apply_setup()
	_apply_cooldown()


func set_cooldown(fraction: float, seconds_text: String) -> void:
	_cd_fraction = clampf(fraction, 0.0, 1.0)
	_cd_text = seconds_text
	if is_node_ready():
		_apply_cooldown()


## The Danish / English word of an ability from ABILITY_<ID>; "" while that key has no translation (never the id).
static func label_for(ability_id: StringName) -> String:
	if ability_id == &"":
		return ""
	var key := "ABILITY_%s" % String(ability_id).to_upper()
	var word := TranslationServer.translate(key)
	return "" if word == key or word == "" else str(word)


## The picture id of an ability: its ART entry, else the ability id itself.
static func art_for(ability_id: StringName) -> StringName:
	return ART.get(ability_id, ability_id)


## The text drawn inside the frame while there is no picture ("" = nothing).
func shown_label() -> String:
	return icon.fallback_label() if is_node_ready() else label_for(icon_id)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and not _setup_pending and icon_id != &"":
		_apply_texts()


func _apply_setup() -> void:
	frame.custom_minimum_size = Vector2(_side, _side)
	icon.id_fallback = false                        # the id is English: no word -> the picture only
	icon.mode = TTItemIcon.Mode.LABEL               # LABEL until art exists
	icon.item_id = art_for(icon_id)
	_apply_texts()


func _apply_texts() -> void:
	icon.display_name = label_for(icon_id)
	key_label.text = _key_text(action)


func _apply_cooldown() -> void:
	var h := (frame.custom_minimum_size.y - 4.0) * _cd_fraction
	veil.offset_top = -h
	cd_label.text = _cd_text


func _key_text(a: StringName) -> String:
	if not InputMap.has_action(a):
		return String(a)
	for e in InputMap.action_get_events(a):
		if e is InputEventMouseButton:
			match (e as InputEventMouseButton).button_index:
				MOUSE_BUTTON_LEFT:
					return tr("KEY_MOUSE_LEFT")
				MOUSE_BUTTON_RIGHT:
					return tr("KEY_MOUSE_RIGHT")
		elif e is InputEventKey:
			var k := e as InputEventKey
			var code := k.physical_keycode if k.physical_keycode != 0 else k.keycode
			if code == KEY_SPACE:
				return tr("KEY_SPACE")
			return OS.get_keycode_string(code)
	return String(a)
