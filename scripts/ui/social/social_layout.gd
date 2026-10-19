class_name SocialLayout
extends RefCounted
## Theme-only layout helpers shared by the social screens.
const Portraits := preload("res://scripts/ui/theme/tt_portraits.gd")
const Fmt := preload("res://scripts/ui/theme/tt_format.gd")
## The design canvas every code-built rect is written in (project.godot viewport); aspect = expand grows the real canvas beyond it.
const DESIGN := Vector2(1280, 720)
static var _chip_theme: Theme

static func label(parent: Node, text: String, variation := "Body", wrap := false) -> Label:
	var node := Label.new()
	node.text = text
	node.theme_type_variation = StringName(variation)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(node)
	return node

static func button(parent: Node, text: String, variation := "PillTab") -> Button:
	var node := Button.new()
	node.text = text
	node.theme_type_variation = StringName(variation)
	parent.add_child(node)
	return node

static func box(parent: Node, vertical := true, gap := 10) -> BoxContainer:
	var node: BoxContainer = VBoxContainer.new() if vertical else HBoxContainer.new()
	node.add_theme_constant_override("separation", gap)
	parent.add_child(node)
	return node

static func panel(parent: Node, variation: String, rect := Rect2()) -> PanelContainer:
	var node := PanelContainer.new()
	node.theme_type_variation = StringName(variation)
	parent.add_child(node)
	if rect.size != Vector2.ZERO:
		place(node, rect)
	return node

## Puts `node` at `rect` of the 1280 x 720 design canvas inside its full-rect parent. An axis on which the rect is centred stays centred on any
## window shape (UIC-02: with aspect = expand a 16:10 fullscreen or a 21:9 window is taller / wider than the design, and a fixed position hugs
## the top-left corner); an off-centre axis keeps its distance from the top / left edge (side panels, HUD plates). Identical at 1280 x 720.
static func place(node: Control, rect: Rect2) -> void:
	var centre := rect.get_center()
	var anchor := Vector2(0.5 if absf(centre.x - DESIGN.x / 2) <= 1.0 else 0.0, 0.5 if absf(centre.y - DESIGN.y / 2) <= 1.0 else 0.0)
	var origin := DESIGN * anchor
	node.anchor_left = anchor.x
	node.anchor_right = anchor.x
	node.anchor_top = anchor.y
	node.anchor_bottom = anchor.y
	node.grow_horizontal = Control.GROW_DIRECTION_BOTH if anchor.x > 0 else Control.GROW_DIRECTION_END
	node.grow_vertical = Control.GROW_DIRECTION_BOTH if anchor.y > 0 else Control.GROW_DIRECTION_END
	node.offset_left = rect.position.x - origin.x
	node.offset_top = rect.position.y - origin.y
	node.offset_right = rect.end.x - origin.x
	node.offset_bottom = rect.end.y - origin.y

static func margin(parent: Node, amount: int) -> MarginContainer:
	var node := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		node.add_theme_constant_override("margin_" + side, amount)
	parent.add_child(node)
	return node

static func portrait(parent: Node, npc: String, width: int, ring := true) -> TextureRect:
	var frame := panel(parent, "FramePortraitRound" if ring else "FrameInk")
	frame.custom_minimum_size = Vector2(width, width)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var texture := TextureRect.new()
	texture.texture = Portraits.portrait(StringName(npc))
	texture.custom_minimum_size = Vector2(width - 8, width - 8)
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(texture)
	return texture

static func chip(parent: Node, text: String, variation := "Chip") -> Label:
	var node := label(parent, text, variation)
	if variation == "ChipRewardRose":
		# Reward chips are PanelContainer tokens in the guide. Project that
		# existing panel style onto a noninteractive Label, without overrides.
		if _chip_theme == null:
			var base: Theme = load("res://assets/ui/theme.tres")
			_chip_theme = base.duplicate() as Theme
			_chip_theme.set_type_variation(&"SocialRewardChip", &"Heavy16")
			_chip_theme.set_stylebox("normal", "SocialRewardChip", base.get_stylebox("panel", "ChipRewardRose"))
		node.theme = _chip_theme
		node.theme_type_variation = &"SocialRewardChip"
	return node

static func hearts(parent: Node, halves: int, width := 26) -> SocialHearts:
	var node := SocialHearts.new()
	node.half_hearts = halves
	node.heart_size = Vector2(width, width - 2)
	parent.add_child(node)
	return node

static func clear(parent: Node) -> void:
	for node in parent.get_children():
		parent.remove_child(node)
		node.queue_free()

static func scrim(parent: Node) -> ColorRect:
	var node := ColorRect.new()
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/blur_scrim.gdshader")
	mat.set_shader_parameter("tint", Color(0.227, 0.192, 0.314, 0.93))
	node.material = mat
	parent.add_child(node)
	return node

static func npc_name(npc: String) -> String:
	return TranslationServer.translate(str(SocialData.npc_row(npc).get("name_key", npc)))

static func item_name(item: String) -> String:
	return TranslationServer.translate(str(ItemKinds.def(item).get("name_key", item)))

static func stage_name(stage: String) -> String:
	return TranslationServer.translate("REL_STAGE_" + stage.to_upper())
