extends Button
## One inventory / hotbar cell (guide "Felter i inventar"). Styles come from the theme variations
## SlotEmpty / SlotFilled (normal) / SlotUncommon / SlotRare / SlotUnique / SlotLegendary; "selected" = pressed (toggle) which
## paints the gold ring INSTEAD of the rarity ring (gold = focus only, addendum 2.1).
## Scene: scenes/ui/components/item_slot.tscn  (children: %Icon, %Pips, %KeyLabel, %CountLabel).
## setup() may be called BEFORE the slot is in the tree (the usual way to build 24 backpack cells: instantiate, setup,
## add_child): the data is kept and the child nodes are filled in `_ready`. Assigning `rarity` later re-themes the tile AND
## the icon (a legendary icon switches to its `_night` variant / pale disc), whatever the order of the assignments was.
##
## `rarity` (normal | uncommon | rare | unique | legendary) picks the tile fill + ring (theme variation, colours from
## Rarity.ui() written by tools/ui/build_theme.gd), the pips (shape + count, bottom-left) and, for legendary, the `_night`
## icon variant / pale disc (TTItemIcon). The item picture is found in the three icon directories (items, home, wardrobe).

## rarity id -> theme type variation of the tile
const VARIATIONS := {
	&"normal": &"SlotFilled", &"uncommon": &"SlotUncommon", &"rare": &"SlotRare", &"unique": &"SlotUnique", &"legendary": &"SlotLegendary",
}
## label variation of the count: legendary is the dark tile, its count is pale
const COUNT_VARIATION := &"Display15"
const COUNT_VARIATION_NIGHT := &"Display15Night"

@onready var item_icon: Control = %Icon
@onready var pips: Control = %Pips
@onready var key_label: Label = %KeyLabel
@onready var count_label: Label = %CountLabel

var item_id: StringName = &""
var amount: int = 0
var rarity: StringName = &"normal":
	set(v):
		rarity = Rarity.normalize(v)
		_apply_rarity()

var _setup_pending := false
var _key_text := ""
var _display_name := ""


func _ready() -> void:
	if _setup_pending:
		_setup_pending = false
		_apply_setup()
	elif rarity != &"normal":
		_apply_rarity()                # `rarity` was assigned before the node was ready


## `rare` (the old boolean) is kept: true = rarity rare unless `p_rarity` is given. `p_rarity` wins.
## Safe before the node is ready (see the header): the nodes are filled when it enters the tree.
func setup(p_item: StringName, p_amount: int, key_text: String = "", rare: bool = false, display_name: String = "", p_rarity: StringName = &"") -> void:
	item_id = p_item
	amount = p_amount if p_item != &"" else 0         # an empty cell holds nothing: amount 0, so no count is shown
	_key_text = key_text
	_display_name = display_name
	rarity = p_rarity if p_rarity != &"" else (&"rare" if rare else &"normal")
	if not is_node_ready():
		_setup_pending = true
		return
	_apply_setup()


func _apply_setup() -> void:
	item_icon.display_name = _display_name
	key_label.text = _key_text
	key_label.visible = _key_text != ""
	count_label.text = str(amount) if amount > 0 else ""   # pass 0 for non-stackable tools (an empty cell has amount 0, see setup)
	_apply_rarity()                    # also hands the rarity to the icon, so it resolves its `_night` variant
	item_icon.item_id = item_id


## setup() for an item defined in Lua: the rarity comes from its definition (ItemKinds.rarity_of).
func setup_item(p_item: StringName, p_amount: int, key_text: String = "") -> void:
	setup(p_item, p_amount, key_text, false, "", ItemKinds.rarity_of(p_item) if p_item != &"" else &"normal")


## The theme variation the tile uses right now (tests).
func current_variation() -> StringName:
	return theme_type_variation


func _apply_rarity() -> void:
	if not is_node_ready():
		return
	item_icon.rarity = rarity          # the icon follows the tile (legendary -> `_night` rim variant or the pale disc)
	if item_id == &"":
		theme_type_variation = &"SlotEmpty"
		pips.set("rarity", &"normal")
	else:
		theme_type_variation = VARIATIONS.get(rarity, &"SlotFilled")
		pips.set("rarity", rarity)
	var night := bool(Rarity.ui(rarity).get("night", false)) and item_id != &""
	count_label.theme_type_variation = COUNT_VARIATION_NIGHT if night else COUNT_VARIATION
